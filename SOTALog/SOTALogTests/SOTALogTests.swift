import XCTest
@testable import SOTALog

// MARK: - BandPlan Tests

final class BandPlanTests: XCTestCase {
    func testBandLookup() {
        XCTAssertEqual(BandPlan.band(for: 14.060), "20m")
        XCTAssertEqual(BandPlan.band(for: 7.030), "40m")
        XCTAssertEqual(BandPlan.band(for: 3.530), "80m")
        XCTAssertEqual(BandPlan.band(for: 21.060), "15m")
        XCTAssertEqual(BandPlan.band(for: 28.060), "10m")
        XCTAssertEqual(BandPlan.band(for: 10.110), "30m")
        XCTAssertEqual(BandPlan.band(for: 1.810), "160m")
        XCTAssertEqual(BandPlan.band(for: 50.060), "6m")
        XCTAssertEqual(BandPlan.band(for: 18.080), "17m")
        XCTAssertEqual(BandPlan.band(for: 24.910), "12m")
    }

    func testOutOfBand() {
        XCTAssertNil(BandPlan.band(for: 0.5))
        XCTAssertNil(BandPlan.band(for: 100.0))
        XCTAssertNil(BandPlan.band(for: 5.0))
    }

    func testDefaultCWFrequenciesAreWithinBand() {
        for bandName in BandPlan.allBands {
            let freq = BandPlan.defaultCWFrequency(for: bandName)
            XCTAssertNotNil(freq, "Missing default CW freq for \(bandName)")
            XCTAssertEqual(BandPlan.band(for: freq!), bandName)
        }
    }
}

// MARK: - MaidenheadConverter Tests

final class MaidenheadConverterTests: XCTestCase {
    func testKnownLocations() {
        // Washington DC area
        let dc = MaidenheadConverter.gridSquare(latitude: 38.9072, longitude: -77.0369)
        XCTAssertTrue(dc.hasPrefix("FM18"), "DC grid should start with FM18, got \(dc)")

        // New York City
        let nyc = MaidenheadConverter.gridSquare(latitude: 40.7128, longitude: -74.0060)
        XCTAssertTrue(nyc.hasPrefix("FN20"), "NYC grid should start with FN20, got \(nyc)")

        // London
        let london = MaidenheadConverter.gridSquare(latitude: 51.5074, longitude: -0.1278)
        XCTAssertTrue(london.hasPrefix("IO91"), "London grid should start with IO91, got \(london)")
    }

    func testGrid4Length() {
        let grid = MaidenheadConverter.grid4(latitude: 35.0, longitude: -80.0)
        XCTAssertEqual(grid.count, 4)
    }

    func testGrid6Length() {
        let grid = MaidenheadConverter.gridSquare(latitude: 35.0, longitude: -80.0)
        XCTAssertEqual(grid.count, 6)
    }
}

// MARK: - CallsignPrefixResolver Tests

final class CallsignPrefixResolverTests: XCTestCase {
    func testUSCallsigns() {
        XCTAssertNotNil(CallsignPrefixResolver.resolve("W1AW"))
        XCTAssertTrue(CallsignPrefixResolver.resolve("K6ABC")?.contains("CA") == true)
        XCTAssertNotNil(CallsignPrefixResolver.resolve("N4XYZ"))
        XCTAssertNotNil(CallsignPrefixResolver.resolve("AA1BB"))
    }

    func testCanadianCallsigns() {
        XCTAssertEqual(CallsignPrefixResolver.resolve("VE3ABC"), "ON")
        XCTAssertEqual(CallsignPrefixResolver.resolve("VA7XYZ"), "BC")
        XCTAssertEqual(CallsignPrefixResolver.resolve("VE1QQ"), "NS")
    }

    func testDXCallsigns() {
        XCTAssertEqual(CallsignPrefixResolver.resolve("G3ABC"), "England")
        XCTAssertEqual(CallsignPrefixResolver.resolve("DL1XYZ"), "Germany")
        XCTAssertEqual(CallsignPrefixResolver.resolve("JA1ABC"), "Japan")
        XCTAssertEqual(CallsignPrefixResolver.resolve("VK2ABC"), "Australia")
    }

    func testShortCallsigns() {
        XCTAssertNil(CallsignPrefixResolver.resolve("A"))
        XCTAssertNil(CallsignPrefixResolver.resolve(""))
    }
}

// MARK: - ADIFFormatter Tests

final class ADIFFormatterTests: XCTestCase {
    func testEncodeQSO() {
        let qso = QSO(
            logId: 1,
            callsign: "W1AW",
            date: "20240101",
            timeOn: "1234",
            frequency: 14.060,
            band: "20m",
            mode: "CW",
            rstSent: "599",
            rstReceived: "579"
        )
        let adif = ADIFFormatter.encode(qso: qso)
        XCTAssertTrue(adif.contains("<CALL:4>W1AW"))
        XCTAssertTrue(adif.contains("<QSO_DATE:8>20240101"))
        XCTAssertTrue(adif.contains("<TIME_ON:4>1234"))
        XCTAssertTrue(adif.contains("<BAND:3>20m"))
        XCTAssertTrue(adif.contains("<MODE:2>CW"))
        XCTAssertTrue(adif.contains("<RST_SENT:3>599"))
        XCTAssertTrue(adif.contains("<RST_RCVD:3>579"))
        XCTAssertTrue(adif.contains("<FREQ:7>14.0600"))
        XCTAssertTrue(adif.contains("<EOR>"))
    }

    func testEncodePOTAFields() {
        let qso = QSO(logId: 1, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m", potaRef: "US-0001")
        let log = Log(myCallsign: "K3ABC", potaReference: "US-4431", parkName: "Prescott NF")
        let adif = ADIFFormatter.encode(qso: qso, log: log)
        XCTAssertTrue(adif.contains("<MY_SIG:4>POTA"))
        XCTAssertTrue(adif.contains("<MY_SIG_INFO:7>US-4431"))
        XCTAssertTrue(adif.contains("<SIG:4>POTA"))
        XCTAssertTrue(adif.contains("<SIG_INFO:7>US-0001"))
    }

    func testDecodeADIF() {
        let adif = """
        Test header
        <ADIF_VER:5>3.1.4<EOH>
        <CALL:4>W1AW<QSO_DATE:8>20240101<TIME_ON:4>1234<BAND:3>20m<MODE:2>CW<RST_SENT:3>599<RST_RCVD:3>579<EOR>
        <CALL:5>K3ABC<QSO_DATE:8>20240102<TIME_ON:4>0000<BAND:3>40m<MODE:2>CW<EOR>
        """
        let records = ADIFFormatter.decode(adif)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0]["CALL"], "W1AW")
        XCTAssertEqual(records[0]["BAND"], "20m")
        XCTAssertEqual(records[1]["CALL"], "K3ABC")
        XCTAssertEqual(records[1]["BAND"], "40m")
    }

    func testFieldsToQSO() {
        let fields: [String: String] = [
            "CALL": "W1AW",
            "QSO_DATE": "20240101",
            "TIME_ON": "1234",
            "BAND": "20m",
            "MODE": "CW",
            "RST_SENT": "599",
            "RST_RCVD": "579",
            "FREQ": "14.060",
            "NAME": "Hiram",
            "QTH": "CT",
        ]
        let qso = ADIFFormatter.qsoFromFields(fields, logId: 1)
        XCTAssertNotNil(qso)
        XCTAssertEqual(qso?.callsign, "W1AW")
        XCTAssertEqual(qso?.frequency, 14.060)
        XCTAssertEqual(qso?.name, "Hiram")
        XCTAssertEqual(qso?.qth, "CT")
    }

    func testRoundTrip() {
        let qso = QSO(
            logId: 1,
            callsign: "VE3ABC",
            date: "20240315",
            timeOn: "1422",
            frequency: 7.030,
            band: "40m",
            mode: "CW",
            rstSent: "599",
            rstReceived: "559",
            name: "John",
            qth: "ON"
        )
        let encoded = ADIFFormatter.encode(qso: qso)
        let decoded = ADIFFormatter.decode(encoded)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0]["CALL"], "VE3ABC")
        XCTAssertEqual(decoded[0]["NAME"], "John")
    }
}

// MARK: - String+Callsign Tests

final class StringCallsignTests: XCTestCase {
    func testSanitizeCallsign() {
        XCTAssertEqual("w1aw".sanitizedCallsign, "W1AW")
        XCTAssertEqual("k3abc!@#".sanitizedCallsign, "K3ABC")
        XCTAssertEqual("ve3/w1aw".sanitizedCallsign, "VE3/W1AW")
        XCTAssertEqual("  spaces  ".sanitizedCallsign, "SPACES")
    }

    func testSanitizeAlphanumeric() {
        XCTAssertEqual("W4C/CM-001".sanitizedAlphanumeric, "W4CCM001")
        XCTAssertEqual("w4c-cm001".sanitizedAlphanumeric, "W4CCM001")
    }
}

// MARK: - Database Tests

final class DatabaseTests: XCTestCase {
    func testDatabaseSetup() throws {
        let db = try AppDatabase.empty()
        XCTAssertNotNil(db)
    }

    func testLogCRUD() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)

        // Create
        var log = Log(date: "20240101", myCallsign: "W1AW", isActive: true)
        try await logRepo.save(&log)
        XCTAssertNotNil(log.id)

        // Read
        let fetched = try await logRepo.fetch(id: log.id!)
        XCTAssertEqual(fetched?.myCallsign, "W1AW")

        // Read active
        let active = try await logRepo.fetchActive()
        XCTAssertEqual(active?.id, log.id)

        // Delete
        try await logRepo.delete(id: log.id!)
        let deleted = try await logRepo.fetch(id: log.id!)
        XCTAssertNil(deleted)
    }

    func testQSOCRUD() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW", isActive: true)
        try await logRepo.save(&log)

        // Create QSO
        var qso = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1234", band: "20m")
        try await qsoRepo.save(&qso)
        XCTAssertNotNil(qso.id)

        // Read
        let count = try await qsoRepo.fetchCount(forLogId: log.id!)
        XCTAssertEqual(count, 1)

        // Fetch all
        let qsos = try await qsoRepo.fetchAll(forLogId: log.id!)
        XCTAssertEqual(qsos.count, 1)
        XCTAssertEqual(qsos[0].callsign, "K3ABC")
    }

    func testCallsignHistory() async throws {
        let db = try AppDatabase.empty()
        let historyRepo = CallsignHistoryRepository(database: db)

        // First QSO
        try await historyRepo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)
        var history = try await historyRepo.fetch(callsign: "W1AW")
        XCTAssertEqual(history?.timesWorked, 1)
        XCTAssertEqual(history?.name, "Hiram")

        // Second QSO
        try await historyRepo.recordQSO(callsign: "W1AW", name: nil, qth: nil, grid: nil)
        history = try await historyRepo.fetch(callsign: "W1AW")
        XCTAssertEqual(history?.timesWorked, 2)
        XCTAssertEqual(history?.name, "Hiram") // Not overwritten by nil
    }

    func testOnlyOneActiveLog() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)

        var log1 = Log(date: "20240101", myCallsign: "W1AW", isActive: true)
        try await logRepo.save(&log1)

        var log2 = Log(date: "20240102", myCallsign: "K3ABC", isActive: true)
        try await logRepo.save(&log2)

        // log1 should now be inactive
        let fetched1 = try await logRepo.fetch(id: log1.id!)
        XCTAssertFalse(fetched1!.isActive)

        let active = try await logRepo.fetchActive()
        XCTAssertEqual(active?.id, log2.id)
    }
}
