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

    func testFetchByQRZLogIdFound() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m", qrzLogId: 12345)
        try await qsoRepo.save(&qso)

        let fetched = try await qsoRepo.fetchByQRZLogId(12345)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.callsign, "K3ABC")
    }

    func testFetchByQRZLogIdNotFound() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let fetched = try await qsoRepo.fetchByQRZLogId(99999)
        XCTAssertNil(fetched)
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

// MARK: - QSORepository importPage

final class QSORepositoryImportPageTests: XCTestCase {
    func testImportPageInsertsNewRecords() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let records: [[String: String]] = [
            [
                "APP_QRZLOG_LOGID": "100",
                "CALL": "W1AW",
                "QSO_DATE": "20240101",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
            ],
            [
                "APP_QRZLOG_LOGID": "101",
                "CALL": "K3ABC",
                "QSO_DATE": "20240101",
                "TIME_ON": "1205",
                "BAND": "40m",
                "MODE": "CW",
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.newCount, 2)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.maxLogId, 101)
    }

    func testImportPageTier1ExactMatchByQRZLogId() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        // Pre-insert a QSO with qrzLogId
        var existing = QSO(callsign: "W1AW", date: "20240101", timeOn: "1200", band: "20m", qrzLogId: 100, syncedToQRZ: true)
        try await qsoRepo.save(&existing)

        // Import page with same qrzLogId but updated name
        let records: [[String: String]] = [
            [
                "APP_QRZLOG_LOGID": "100",
                "CALL": "W1AW",
                "QSO_DATE": "20240101",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "NAME": "Hiram",
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.newCount, 0)
        XCTAssertEqual(result.updatedCount, 1)

        let fetched = try await qsoRepo.fetchByQRZLogId(100)
        XCTAssertEqual(fetched?.name, "Hiram")
    }

    func testImportPageTier2SemanticMatch() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        // Pre-insert a QSO without qrzLogId (locally created)
        var existing = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m")
        try await qsoRepo.save(&existing)

        // Import page with matching callsign+band+date+time — should semantic-match
        let records: [[String: String]] = [
            [
                "APP_QRZLOG_LOGID": "200",
                "CALL": "K3ABC",
                "QSO_DATE": "20240101",
                "TIME_ON": "1202",  // within ±5 min
                "BAND": "20m",
                "MODE": "CW",
                "NAME": "John",
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.newCount, 0)
        XCTAssertEqual(result.updatedCount, 1)

        // Original record should now have qrzLogId linked
        let fetched = try await qsoRepo.fetchByQRZLogId(200)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.logId, log.id)  // preserved attachment
        XCTAssertEqual(fetched?.name, "John")
    }

    func testImportPageInsertsRecordsMissingLogId() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let records: [[String: String]] = [
            [
                // No APP_QRZLOG_LOGID — still imported via tier 3
                "CALL": "W1AW",
                "QSO_DATE": "20240101",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.newCount, 1)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.maxLogId, 0)
    }

    func testImportPageSkipsRecordsMissingRequiredFields() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let records: [[String: String]] = [
            [
                "APP_QRZLOG_LOGID": "100",
                // Missing CALL, QSO_DATE, TIME_ON — qsoFromFields returns nil
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.newCount, 0)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.maxLogId, 100)  // maxLogId still tracked
    }

    func testImportPageTracksMaxLogId() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let records: [[String: String]] = [
            [
                "APP_QRZLOG_LOGID": "50",
                "CALL": "W1AW",
                "QSO_DATE": "20240101",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
            ],
            [
                "APP_QRZLOG_LOGID": "300",
                "CALL": "K3ABC",
                "QSO_DATE": "20240101",
                "TIME_ON": "1205",
                "BAND": "40m",
                "MODE": "CW",
            ],
            [
                "APP_QRZLOG_LOGID": "150",
                "CALL": "N4XYZ",
                "QSO_DATE": "20240101",
                "TIME_ON": "1210",
                "BAND": "15m",
                "MODE": "CW",
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.maxLogId, 300)
    }

    func testImportPageEmptyRecords() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let result = try await qsoRepo.importPage([])
        XCTAssertEqual(result.newCount, 0)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.maxLogId, 0)
    }

    func testImportPageSemanticMatchPreservesLocalFields() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        // Local QSO has notes and potaRef that QRZ doesn't
        var existing = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m", potaRef: "US-4431", notes: "My local notes")
        try await qsoRepo.save(&existing)

        // QRZ record has no notes or potaRef
        let records: [[String: String]] = [
            [
                "APP_QRZLOG_LOGID": "200",
                "CALL": "K3ABC",
                "QSO_DATE": "20240101",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
            ],
        ]

        let result = try await qsoRepo.importPage(records)
        XCTAssertEqual(result.updatedCount, 1)

        let fetched = try await qsoRepo.fetchByQRZLogId(200)
        XCTAssertEqual(fetched?.potaRef, "US-4431")  // preserved
        XCTAssertEqual(fetched?.notes, "My local notes")  // preserved
    }
}

// MARK: - QSORepository Sync Cursor

final class QSORepositorySyncCursorTests: XCTestCase {
    func testSyncCursorRoundTrip() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let initial = try await qsoRepo.lastSyncedQRZLogId()
        XCTAssertEqual(initial, 0)

        try await qsoRepo.saveLastSyncedQRZLogId(12345)
        let saved = try await qsoRepo.lastSyncedQRZLogId()
        XCTAssertEqual(saved, 12345)
    }

    func testLastSyncDateUpdates() async throws {
        let db = try AppDatabase.empty()
        let qsoRepo = QSORepository(database: db)

        let initial = try await qsoRepo.lastSyncDate()
        XCTAssertNil(initial)

        try await qsoRepo.saveLastSyncedQRZLogId(1)
        let after = try await qsoRepo.lastSyncDate()
        XCTAssertNotNil(after)
    }

    func testDeleteAllUnattached() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        // Attached QSO
        var attached = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m")
        try await qsoRepo.save(&attached)

        // Unattached QSO (logId = nil — from QRZ download)
        var unattached = QSO(callsign: "N4XYZ", date: "20240101", timeOn: "1205", band: "40m")
        try await qsoRepo.save(&unattached)

        try await qsoRepo.deleteAllUnattached()

        let fetchedAttached = try await qsoRepo.fetch(id: attached.id!)
        XCTAssertNotNil(fetchedAttached)

        let fetchedUnattached = try await qsoRepo.fetch(id: unattached.id!)
        XCTAssertNil(fetchedUnattached)
    }

    func testClearAllSyncState() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)

        var qso = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m", qrzLogId: 100, syncedToQRZ: true)
        try await qsoRepo.save(&qso)

        try await qsoRepo.clearAllSyncState()

        let fetched = try await qsoRepo.fetch(id: qso.id!)
        XCTAssertEqual(fetched?.syncedToQRZ, false)
        XCTAssertNil(fetched?.qrzLogId)
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
