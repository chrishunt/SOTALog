import Foundation
import GRDB

public struct ReferenceRepository {
    public let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - POTA Parks

    public func searchParks(query: String, limit: Int = 20) async throws -> [POTAPark] {
        let normalized = POTAPark.normalize(query)
        return try await database.dbWriter.read { db in
            let pattern = "%\(normalized)%"
            let namePattern = "%\(query)%"
            return try POTAPark
                .filter(Column("referenceNormalized").like(pattern) || Column("name").like(namePattern))
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func fetchPark(reference: String) async throws -> POTAPark? {
        try await database.dbWriter.read { db in
            try POTAPark.fetchOne(db, id: reference)
        }
    }

    public func fetchParkByNormalized(_ normalized: String) async throws -> POTAPark? {
        try await database.dbWriter.read { db in
            try POTAPark
                .filter(Column("referenceNormalized") == normalized.uppercased())
                .fetchOne(db)
        }
    }

    public func importParks(_ parks: [POTAPark]) async throws {
        try await database.dbWriter.write { db in
            for park in parks {
                try park.save(db)
            }
        }
    }

    public func parkCount() async throws -> Int {
        try await database.dbWriter.read { db in
            try POTAPark.fetchCount(db)
        }
    }

    public func deleteAllParks() async throws {
        _ = try await database.dbWriter.write { db in
            try POTAPark.deleteAll(db)
        }
    }

    public func nearbyParks(latitude: Double, longitude: Double, limit: Int = 10) async throws -> [POTAPark] {
        try await database.dbWriter.read { db in
            let delta = 1.0 // ~111 km bounding box
            let cosLat = cos(latitude * .pi / 180)
            let cosLatSq = cosLat * cosLat
            return try POTAPark
                .filter(
                    Column("latitude") != nil &&
                    Column("longitude") != nil &&
                    Column("latitude") >= latitude - delta &&
                    Column("latitude") <= latitude + delta &&
                    Column("longitude") >= longitude - delta &&
                    Column("longitude") <= longitude + delta
                )
                .order(sql: """
                    (latitude - ?) * (latitude - ?) + \
                    (longitude - ?) * (longitude - ?) * ?
                    """, arguments: [latitude, latitude, longitude, longitude, cosLatSq])
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func enrichParksWithCoordinates(_ coords: [(reference: String, latitude: Double, longitude: Double)]) async throws {
        try await database.dbWriter.write { db in
            let stmt = try db.makeStatement(sql: """
                UPDATE potaPark SET latitude = ?, longitude = ? WHERE reference = ?
                """)
            for coord in coords {
                try stmt.execute(arguments: [coord.latitude, coord.longitude, coord.reference])
            }
        }
    }

    // MARK: - SOTA Summits

    public func searchSummits(query: String, limit: Int = 20) async throws -> [SOTASummit] {
        let normalized = SOTASummit.normalize(query)
        return try await database.dbWriter.read { db in
            let pattern = "%\(normalized)%"
            return try SOTASummit
                .filter(Column("codeNormalized").like(pattern) || Column("name").like(pattern))
                .limit(limit)
                .fetchAll(db)
        }
    }

    public func fetchSummit(code: String) async throws -> SOTASummit? {
        try await database.dbWriter.read { db in
            try SOTASummit.fetchOne(db, id: code)
        }
    }

    public func fetchSummitByNormalized(_ normalized: String) async throws -> SOTASummit? {
        try await database.dbWriter.read { db in
            try SOTASummit
                .filter(Column("codeNormalized") == normalized.uppercased())
                .fetchOne(db)
        }
    }

    public func importSummits(_ summits: [SOTASummit]) async throws {
        try await database.dbWriter.write { db in
            for summit in summits {
                try summit.save(db)
            }
        }
    }

    public func summitCount() async throws -> Int {
        try await database.dbWriter.read { db in
            try SOTASummit.fetchCount(db)
        }
    }

    public func deleteAllSummits() async throws {
        _ = try await database.dbWriter.write { db in
            try SOTASummit.deleteAll(db)
        }
    }

    public func nearbySummits(latitude: Double, longitude: Double, limit: Int = 10) async throws -> [SOTASummit] {
        try await database.dbWriter.read { db in
            let delta = 1.0
            let cosLat = cos(latitude * .pi / 180)
            let cosLatSq = cosLat * cosLat
            return try SOTASummit
                .filter(
                    Column("latitude") != nil &&
                    Column("longitude") != nil &&
                    Column("latitude") >= latitude - delta &&
                    Column("latitude") <= latitude + delta &&
                    Column("longitude") >= longitude - delta &&
                    Column("longitude") <= longitude + delta
                )
                .order(sql: """
                    (latitude - ?) * (latitude - ?) + \
                    (longitude - ?) * (longitude - ?) * ?
                    """, arguments: [latitude, latitude, longitude, longitude, cosLatSq])
                .limit(limit)
                .fetchAll(db)
        }
    }

    // MARK: - Metadata

    public func fetchMetadata(key: String) async throws -> ReferenceMetadata? {
        try await database.dbWriter.read { db in
            try ReferenceMetadata.filter(Column("key") == key).fetchOne(db)
        }
    }

    public func saveMetadata(_ metadata: ReferenceMetadata) async throws {
        try await database.dbWriter.write { db in
            try metadata.save(db)
        }
    }
}
