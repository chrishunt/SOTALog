import XCTest
@testable import SOTALog

// MARK: - Log Computed Properties

final class LogComputedTests: XCTestCase {
    func testIsPOTA() {
        let log = Log(myCallsign: "W1AW", potaReference: "US-4431")
        XCTAssertTrue(log.isPOTA)
        XCTAssertFalse(log.isSOTA)
    }

    func testIsSOTA() {
        let log = Log(myCallsign: "W1AW", sotaReference: "W4C/CM-001")
        XCTAssertFalse(log.isPOTA)
        XCTAssertTrue(log.isSOTA)
    }

    func testIsBothPOTAAndSOTA() {
        let log = Log(myCallsign: "W1AW", potaReference: "US-4431", sotaReference: "W4C/CM-001")
        XCTAssertTrue(log.isPOTA)
        XCTAssertTrue(log.isSOTA)
    }

    func testReferenceDisplayPOTAOnly() {
        let log = Log(myCallsign: "W1AW", potaReference: "US-4431")
        XCTAssertEqual(log.referenceDisplay, "US-4431")
    }

    func testReferenceDisplaySOTAOnly() {
        let log = Log(myCallsign: "W1AW", sotaReference: "W4C/CM-001")
        XCTAssertEqual(log.referenceDisplay, "W4C/CM-001")
    }

    func testReferenceDisplayBoth() {
        let log = Log(myCallsign: "W1AW", potaReference: "US-4431", sotaReference: "W4C/CM-001")
        XCTAssertEqual(log.referenceDisplay, "US-4431 · W4C/CM-001")
    }

    func testReferenceDisplayNeither() {
        let log = Log(myCallsign: "W1AW")
        XCTAssertNil(log.referenceDisplay)
    }
}

// MARK: - POTAPark Normalization

final class POTAParkNormalizationTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(POTAPark.normalize("US-4431"), "US4431")
    }

    func testNormalizeLowercase() {
        XCTAssertEqual(POTAPark.normalize("us-4431"), "US4431")
    }

    func testNormalizeAlreadyNormalized() {
        XCTAssertEqual(POTAPark.normalize("US4431"), "US4431")
    }

    func testDisplayName() {
        let park = POTAPark(reference: "US-4431", name: "Prescott NF")
        XCTAssertEqual(park.displayName, "US-4431 Prescott NF")
    }
}

// MARK: - SOTASummit Normalization

final class SOTASummitNormalizationTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(SOTASummit.normalize("W4C/CM-001"), "W4CCM001")
    }

    func testNormalizeLowercase() {
        XCTAssertEqual(SOTASummit.normalize("w4c/cm-001"), "W4CCM001")
    }

    func testNormalizeAlreadyNormalized() {
        XCTAssertEqual(SOTASummit.normalize("W4CCM001"), "W4CCM001")
    }

    func testDisplayName() {
        let summit = SOTASummit(code: "W4C/CM-001", name: "Mount Mitchell")
        XCTAssertEqual(summit.displayName, "W4C/CM-001 Mount Mitchell")
    }
}

// MARK: - QRZCallsignResult

final class QRZCallsignResultTests: XCTestCase {
    func testNameBothNames() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: "Hiram", nickname: nil, lastName: "Maxim", city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertEqual(result.name, "Hiram Maxim")
    }

    func testNameFirstOnly() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: "Hiram", nickname: nil, lastName: nil, city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertEqual(result.name, "Hiram")
    }

    func testNameLastOnly() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: nil, nickname: nil, lastName: "Maxim", city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertEqual(result.name, "Maxim")
    }

    func testNameBothNil() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: nil, nickname: nil, lastName: nil, city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertNil(result.name)
    }

    func testNameBothEmpty() {
        // compactMap keeps empty strings; joined produces " " which nilIfEmpty doesn't trim
        let result = QRZCallsignResult(callsign: "W1AW", firstName: "", nickname: nil, lastName: "", city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertEqual(result.name, " ")
    }

    func testNicknameOverridesFirstAndLast() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: "Hiram", nickname: "Hi", lastName: "Maxim", city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertEqual(result.name, "Hi")
    }

    func testQTHPrefersState() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: nil, nickname: nil, lastName: nil, city: nil, state: "CT", country: "United States", grid: nil, county: nil)
        XCTAssertEqual(result.qth, "CT")
    }

    func testQTHFallsBackToCountry() {
        let result = QRZCallsignResult(callsign: "G3ABC", firstName: nil, nickname: nil, lastName: nil, city: nil, state: nil, country: "England", grid: nil, county: nil)
        XCTAssertEqual(result.qth, "England")
    }

    func testQTHBothNil() {
        let result = QRZCallsignResult(callsign: "W1AW", firstName: nil, nickname: nil, lastName: nil, city: nil, state: nil, country: nil, grid: nil, county: nil)
        XCTAssertNil(result.qth)
    }
}
