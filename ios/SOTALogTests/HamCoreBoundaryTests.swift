import XCTest
@testable import SOTALog
import HamCore

/// The seams between this app and the ham-core package: what the app hands
/// the package and what it expects back. How the package works is tested in
/// its own repository.
final class HamCoreBoundaryTests: XCTestCase {
    func testOnDiskDatabaseRoundTripsAQSOAcrossReopen() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sotalog-boundary-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("db.sqlite")

        var qso = QSO(callsign: "K6ARK", date: "20260914", timeOn: "1504",
                      frequency: 14.062, band: "20m", mode: "CW", sotaRef: "W6/CT-002")
        do {
            let database = try LogbookDatabase.onDisk(at: url)
            try await QSORepository(database: database).save(&qso)
        }

        let reopened = try LogbookDatabase.onDisk(at: url)
        let fetched = try await QSORepository(database: reopened).fetch(id: qso.id!)
        XCTAssertEqual(fetched?.callsign, "K6ARK")
        XCTAssertEqual(fetched?.sotaRef, "W6/CT-002")
    }

    func testTheAppIdentifiesItselfToServicesAndInExports() {
        XCTAssertTrue(SOTALogIdentity.userAgent.hasPrefix("SOTA Log/"))
        XCTAssertEqual(APIClient.sotaLog.userAgent, SOTALogIdentity.userAgent)

        let name = ADIFFormatter.exportAllFilename(software: .sotaLog, date: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(name, "SOTALog_19700101_0000Z.adi", "the export filename keeps its historical prefix")

        let header = ADIFFormatter.encodeFile(qsos: [], software: .sotaLog)
        XCTAssertTrue(header.contains("<PROGRAMID:8>SOTA Log"))
        let version = SOTALogIdentity.version
        XCTAssertTrue(header.contains("<PROGRAMVERSION:\(version.count)>\(version)"))
    }

    func testMacroDefaultsSeedOnceAndRestoreOnePosition() async throws {
        let repo = CWMacroRepository(database: try LogbookDatabase.empty())

        try await repo.seedIfEmpty(CWMacro.defaults)
        try await repo.seedIfEmpty(CWMacro.defaults)
        var macros = try await repo.fetchAll()
        XCTAssertEqual(macros.map(\.label), ["CQ", "?", "EXCH", "TU", "CALL", "S2S"])

        var edited = macros[0]
        edited.template = "CQ CQ"
        try await repo.save(&edited)
        try await repo.replace(position: 0, with: CWMacro.defaults[0])
        macros = try await repo.fetchAll()
        XCTAssertEqual(macros.count, 6)
        XCTAssertEqual(macros[0].template, CWMacro.defaults[0].template)
    }
}
