import XCTest
@testable import SOTALog

// MARK: - ReferenceRepository — Parks

final class ReferenceRepositoryParkTests: XCTestCase {
    func testImportAndSearchParks() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        let parks = [
            POTAPark(reference: "US-0001", name: "Acadia NP", referenceNormalized: "US0001"),
            POTAPark(reference: "US-4431", name: "Prescott NF", referenceNormalized: "US4431"),
        ]
        try await repo.importParks(parks)

        let results = try await repo.searchParks(query: "US-4431")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Prescott NF")
    }

    func testSearchParksByName() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        try await repo.importParks([
            POTAPark(reference: "US-0001", name: "Acadia NP", referenceNormalized: "US0001"),
        ])

        let results = try await repo.searchParks(query: "Acadia")
        XCTAssertEqual(results.count, 1)
    }

    func testFetchParkByNormalized() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        try await repo.importParks([
            POTAPark(reference: "US-4431", name: "Prescott NF", referenceNormalized: "US4431"),
        ])

        let found = try await repo.fetchParkByNormalized("US4431")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "Prescott NF")
    }

    func testFetchParkByNormalizedNotFound() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        let found = try await repo.fetchParkByNormalized("XX9999")
        XCTAssertNil(found)
    }

    func testParkCountAndDeleteAll() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        try await repo.importParks([
            POTAPark(reference: "US-0001", name: "Acadia NP", referenceNormalized: "US0001"),
            POTAPark(reference: "US-0002", name: "Yellowstone NP", referenceNormalized: "US0002"),
        ])

        let countBefore = try await repo.parkCount()
        XCTAssertEqual(countBefore, 2)

        try await repo.deleteAllParks()
        let countAfter = try await repo.parkCount()
        XCTAssertEqual(countAfter, 0)
    }
}

// MARK: - ReferenceRepository — Summits

final class ReferenceRepositorySummitTests: XCTestCase {
    func testImportAndSearchSummits() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        try await repo.importSummits([
            SOTASummit(code: "W4C/CM-001", codeNormalized: "W4CCM001", name: "Mount Mitchell"),
        ])

        let results = try await repo.searchSummits(query: "W4C/CM-001")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Mount Mitchell")
    }

    func testFetchSummitByNormalized() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        try await repo.importSummits([
            SOTASummit(code: "W4C/CM-001", codeNormalized: "W4CCM001", name: "Mount Mitchell"),
        ])

        let found = try await repo.fetchSummitByNormalized("W4CCM001")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.code, "W4C/CM-001")
    }

    func testFetchSummitByNormalizedNotFound() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        let found = try await repo.fetchSummitByNormalized("XX000")
        XCTAssertNil(found)
    }

    func testSummitCountAndDeleteAll() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        try await repo.importSummits([
            SOTASummit(code: "W4C/CM-001", codeNormalized: "W4CCM001", name: "Mount Mitchell"),
            SOTASummit(code: "G/LD-001", codeNormalized: "GLD001", name: "Helvellyn"),
        ])

        let countBefore = try await repo.summitCount()
        XCTAssertEqual(countBefore, 2)

        try await repo.deleteAllSummits()
        let countAfter = try await repo.summitCount()
        XCTAssertEqual(countAfter, 0)
    }
}

// MARK: - ReferenceRepository — Metadata

final class ReferenceRepositoryMetadataTests: XCTestCase {
    func testMetadataRoundTrip() async throws {
        let db = try AppDatabase.empty()
        let repo = ReferenceRepository(database: db)

        let now = Date()
        let metadata = ReferenceMetadata(key: "potaParks", lastRefreshed: now, recordCount: 42)
        try await repo.saveMetadata(metadata)

        let fetched = try await repo.fetchMetadata(key: "potaParks")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.recordCount, 42)
    }
}

// MARK: - QSORepository Extensions

final class QSORepositoryExtendedTests: XCTestCase {
    func testFetchUnsynced() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso1 = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m", syncedToQRZ: false)
        var qso2 = QSO(logId: log.id!, callsign: "N4XYZ", date: "20240101", timeOn: "1201", band: "20m", syncedToQRZ: true)
        try await qsoRepo.save(&qso1)
        try await qsoRepo.save(&qso2)

        let unsynced = try await qsoRepo.fetchUnsynced()
        XCTAssertEqual(unsynced.count, 1)
        XCTAssertEqual(unsynced[0].callsign, "K3ABC")
    }

    func testFetchUnsyncedAscendingOrder() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso1 = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m")
        var qso2 = QSO(logId: log.id!, callsign: "N4XYZ", date: "20240101", timeOn: "1201", band: "20m")
        try await qsoRepo.save(&qso1)
        try await qsoRepo.save(&qso2)

        let unsynced = try await qsoRepo.fetchUnsynced()
        XCTAssertEqual(unsynced.count, 2)
        XCTAssertTrue(unsynced[0].id! < unsynced[1].id!)
    }

    func testMarkSynced() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m")
        try await qsoRepo.save(&qso)

        try await qsoRepo.markSynced(id: qso.id!, qrzLogId: 12345)

        let fetched = try await qsoRepo.fetch(id: qso.id!)
        XCTAssertEqual(fetched?.syncedToQRZ, true)
        XCTAssertEqual(fetched?.qrzLogId, 12345)
    }

    func testDeleteQSO() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m")
        try await qsoRepo.save(&qso)

        try await qsoRepo.delete(id: qso.id!)
        let fetched = try await qsoRepo.fetch(id: qso.id!)
        XCTAssertNil(fetched)
    }

    func testFetchById() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m")
        try await qsoRepo.save(&qso)

        let fetched = try await qsoRepo.fetch(id: qso.id!)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.callsign, "K3ABC")
    }
}

// MARK: - QSORepository Full Refresh Import

final class QSORepositoryFullRefreshTests: XCTestCase {

    private func seedRefs(_ db: AppDatabase) async throws {
        let refRepo = ReferenceRepository(database: db)
        try await refRepo.importParks([
            POTAPark(reference: "US-4431", name: "Prescott NF", referenceNormalized: "US4431"),
            POTAPark(reference: "US-0001", name: "Acadia NP", referenceNormalized: "US0001"),
        ])
        try await refRepo.importSummits([
            SOTASummit(code: "W4C/CM-001", codeNormalized: "W4CCM001", name: "Mount Mitchell"),
        ])
    }

    func testDeletesSyncedPreservesUnsynced() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)
        try await seedRefs(db)

        var log = Log(date: "20240315", myCallsign: "W1AW", potaReference: "US-4431")
        try await logRepo.save(&log)

        var synced = QSO(logId: log.id!, callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m", syncedToQRZ: true)
        var unsynced = QSO(logId: log.id!, callsign: "N4XYZ", date: "20240315", timeOn: "1205", band: "20m", syncedToQRZ: false)
        try await qsoRepo.save(&synced)
        try await qsoRepo.save(&unsynced)

        let result = try await qsoRepo.fullRefreshImport(groupedQSOs: [], unattachedQSOs: [])

        XCTAssertEqual(result.importedCount, 0)

        // Synced QSO should be deleted
        let fetchedSynced = try await qsoRepo.fetch(id: synced.id!)
        XCTAssertNil(fetchedSynced)

        // Unsynced QSO should be preserved
        let fetchedUnsynced = try await qsoRepo.fetch(id: unsynced.id!)
        XCTAssertNotNil(fetchedUnsynced)
    }

    func testDeletesEmptyLogsPreservesLogsWithUnsyncedQSOs() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)
        try await seedRefs(db)

        // Log with only synced QSOs (should be deleted)
        var logSynced = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&logSynced)
        var syncedQSO = QSO(logId: logSynced.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m", syncedToQRZ: true)
        try await qsoRepo.save(&syncedQSO)

        // Log with an unsynced QSO (should be preserved)
        var logUnsynced = Log(date: "20240102", myCallsign: "W1AW")
        try await logRepo.save(&logUnsynced)
        var unsyncedQSO = QSO(logId: logUnsynced.id!, callsign: "N4XYZ", date: "20240102", timeOn: "1200", band: "20m", syncedToQRZ: false)
        try await qsoRepo.save(&unsyncedQSO)

        _ = try await qsoRepo.fullRefreshImport(groupedQSOs: [], unattachedQSOs: [])

        let fetchedSyncedLog = try await logRepo.fetch(id: logSynced.id!)
        XCTAssertNil(fetchedSyncedLog)

        let fetchedUnsyncedLog = try await logRepo.fetch(id: logUnsynced.id!)
        XCTAssertNotNil(fetchedUnsyncedLog)
    }

    func testCreatesActivationsWithCorrectRefs() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)
        try await seedRefs(db)

        let key = SyncImporter.ActivationKey(
            date: "20240315",
            potaReference: "US-4431",
            sotaReference: nil,
            stationCallsign: "W1AW",
            myGrid: "DM62"
        )
        let record = SyncImporter.ParsedQSORecord(
            qso: QSO(callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m"),
            rawFields: ["CALL": "K3ABC", "QSO_DATE": "20240315", "TIME_ON": "1200", "BAND": "20m"]
        )

        let result = try await qsoRepo.fullRefreshImport(
            groupedQSOs: [(key: key, qsos: [record])],
            unattachedQSOs: []
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.activationsCreated, 1)

        let logs = try await LogRepository(database: db).fetchAll()
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].potaReference, "US-4431")
        XCTAssertEqual(logs[0].parkName, "Prescott NF")
        XCTAssertEqual(logs[0].myCallsign, "W1AW")
        XCTAssertEqual(logs[0].myGrid, "DM62")
    }

    func testReusesExistingActivation() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)
        try await seedRefs(db)

        // Pre-create a log with an unsynced QSO
        var existingLog = Log(date: "20240315", myCallsign: "W1AW", potaReference: "US-4431")
        try await logRepo.save(&existingLog)
        var localQSO = QSO(logId: existingLog.id!, callsign: "LOCAL", date: "20240315", timeOn: "1100", band: "20m", syncedToQRZ: false)
        try await qsoRepo.save(&localQSO)

        let key = SyncImporter.ActivationKey(
            date: "20240315",
            potaReference: "US-4431",
            sotaReference: nil,
            stationCallsign: "W1AW",
            myGrid: nil
        )
        let record = SyncImporter.ParsedQSORecord(
            qso: QSO(callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m"),
            rawFields: ["CALL": "K3ABC", "QSO_DATE": "20240315", "TIME_ON": "1200", "BAND": "20m"]
        )

        let result = try await qsoRepo.fullRefreshImport(
            groupedQSOs: [(key: key, qsos: [record])],
            unattachedQSOs: []
        )

        XCTAssertEqual(result.activationsReused, 1)
        XCTAssertEqual(result.activationsCreated, 0)

        // Verify QSO was added to existing log
        let qsos = try await qsoRepo.fetchAll(forLogId: existingLog.id!)
        XCTAssertEqual(qsos.count, 2)  // local + imported
    }

    func testUnattachedQSOsSavedWithNilLogId() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let record = SyncImporter.ParsedQSORecord(
            qso: QSO(callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m"),
            rawFields: ["CALL": "K3ABC", "QSO_DATE": "20240315", "TIME_ON": "1200", "BAND": "20m"]
        )

        let result = try await qsoRepo.fullRefreshImport(
            groupedQSOs: [],
            unattachedQSOs: [record]
        )

        XCTAssertEqual(result.importedCount, 1)

        let unsynced = try await qsoRepo.fetchUnsynced()
        XCTAssertEqual(unsynced.count, 0)  // it IS synced

        // Verify it was saved — fetch all QSOs by reading the DB directly
        let allQSOs = try await db.dbWriter.read { db in
            try QSO.fetchAll(db)
        }
        XCTAssertEqual(allQSOs.count, 1)
        XCTAssertNil(allQSOs[0].logId)
        XCTAssertTrue(allQSOs[0].syncedToQRZ)
    }

    func testLastSyncDateUpdates() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let initial = try await qsoRepo.lastSyncDate()
        XCTAssertNil(initial)

        try await qsoRepo.saveLastSyncedQRZLogId(0)
        let after = try await qsoRepo.lastSyncDate()
        XCTAssertNotNil(after)
    }
}

// MARK: - CallsignHistoryRepository Extensions

final class CallsignHistoryExtendedTests: XCTestCase {
    func testUpdateFromLookupCreatesNew() async throws {
        let db = try AppDatabase.empty()
        let repo = CallsignHistoryRepository(database: db)

        try await repo.updateFromLookup(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)

        let history = try await repo.fetch(callsign: "W1AW")
        XCTAssertNotNil(history)
        XCTAssertEqual(history?.timesWorked, 0)
        XCTAssertEqual(history?.name, "Hiram")
    }

    func testUpdateFromLookupDoesNotIncrementExisting() async throws {
        let db = try AppDatabase.empty()
        let repo = CallsignHistoryRepository(database: db)

        try await repo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)
        try await repo.updateFromLookup(callsign: "W1AW", name: "Hiram P Maxim", qth: "CT", grid: "FN31")

        let history = try await repo.fetch(callsign: "W1AW")
        XCTAssertEqual(history?.timesWorked, 1)
        XCTAssertEqual(history?.name, "Hiram P Maxim")
        XCTAssertEqual(history?.grid, "FN31")
    }

    func testRecordQSODoesNotOverwriteWithNil() async throws {
        let db = try AppDatabase.empty()
        let repo = CallsignHistoryRepository(database: db)

        try await repo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: "FN31")
        try await repo.recordQSO(callsign: "W1AW", name: nil, qth: nil, grid: nil)

        let history = try await repo.fetch(callsign: "W1AW")
        XCTAssertEqual(history?.name, "Hiram")
        XCTAssertEqual(history?.qth, "CT")
        XCTAssertEqual(history?.grid, "FN31")
    }

    func testUpdateFromLookupDoesNotOverwriteWithNil() async throws {
        let db = try AppDatabase.empty()
        let repo = CallsignHistoryRepository(database: db)

        try await repo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)
        try await repo.updateFromLookup(callsign: "W1AW", name: nil, qth: nil, grid: nil)

        let history = try await repo.fetch(callsign: "W1AW")
        XCTAssertEqual(history?.name, "Hiram")
        XCTAssertEqual(history?.qth, "CT")
    }
}
