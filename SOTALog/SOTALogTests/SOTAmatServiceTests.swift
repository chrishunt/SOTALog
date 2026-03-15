import XCTest
@testable import SOTALog

final class SOTAmatServiceTests: XCTestCase {

    // MARK: - SOTA only

    func testSOTASpot() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: nil
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.062 CW")
    }

    func testSOTASpotWithComment() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "Running 5W"
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'Running 5W")
    }

    // MARK: - POTA only

    func testPOTASpot() {
        let log = Log(myCallsign: "AB1CD", potaReference: "US-4431")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: nil
        )
        XCTAssertEqual(result, "PotaPostSpot AB1CD US-4431 14.062 CW")
    }

    func testPOTASpotWithComment() {
        let log = Log(myCallsign: "AB1CD", potaReference: "US-4431")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "7.030", mode: "CW", comment: "On the trail"
        )
        XCTAssertEqual(result, "PotaPostSpot AB1CD US-4431 7.030 CW 'On the trail")
    }

    // MARK: - Dual activation

    func testDualActivationSpot() {
        let log = Log(
            myCallsign: "AB1CD",
            potaReference: "US-4431",
            sotaReference: "W4C/CM-001"
        )
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: nil
        )
        XCTAssertEqual(
            result,
            "SotaPostSpot AB1CD W4C/CM-001 14.062 CW; PotaPostSpot AB1CD US-4431 14.062 CW"
        )
    }

    func testDualActivationWithComment() {
        let log = Log(
            myCallsign: "AB1CD",
            potaReference: "US-4431",
            sotaReference: "W4C/CM-001"
        )
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "Running 5W"
        )
        XCTAssertEqual(
            result,
            "SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'Running 5W; PotaPostSpot AB1CD US-4431 14.062 CW 'Running 5W"
        )
    }

    // MARK: - No reference

    func testNilWhenNoReferences() {
        let log = Log(myCallsign: "AB1CD")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: nil
        )
        XCTAssertNil(result)
    }

    // MARK: - Comment sanitization

    func testSanitizesReservedCharsFromComment() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "it's a nice; day, here"
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'its a nice day here")
    }

    func testSanitizesSmartQuotesFromComment() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW",
            comment: "it\u{2019}s a \u{201C}nice\u{201D} day"
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'its a nice day")
    }

    func testEmptyCommentAfterSanitization() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: ";;,'"
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.062 CW")
    }

    func testWhitespaceOnlyComment() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "   "
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.062 CW")
    }

    // MARK: - QRT inference

    func testQRTInferenceSOTA() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "QRT thanks for the contacts"
        )
        XCTAssertEqual(
            result,
            "SotaPostSpot AB1CD W4C/CM-001 14.062 QRT 'QRT thanks for the contacts"
        )
    }

    func testQRTInferencePOTA() {
        let log = Log(myCallsign: "AB1CD", potaReference: "US-4431")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "QRT thanks for the contacts"
        )
        XCTAssertEqual(
            result,
            "PotaPostSpot AB1CD US-4431 14.062 CW 'QRT thanks for the contacts"
        )
    }

    func testQRTInferenceCaseInsensitive() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "SSB", comment: "going qrt now"
        )
        XCTAssertEqual(
            result,
            "SotaPostSpot AB1CD W4C/CM-001 14.062 QRT 'going qrt now"
        )
    }

    func testQRTDualActivation() {
        let log = Log(
            myCallsign: "AB1CD",
            potaReference: "US-4431",
            sotaReference: "W4C/CM-001"
        )
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.062", mode: "CW", comment: "QRT thanks"
        )
        XCTAssertEqual(
            result,
            "SotaPostSpot AB1CD W4C/CM-001 14.062 QRT 'QRT thanks; PotaPostSpot AB1CD US-4431 14.062 CW 'QRT thanks"
        )
    }

    // MARK: - SSB mode

    func testSSBMode() {
        let log = Log(myCallsign: "AB1CD", sotaReference: "W4C/CM-001")
        let result = SOTAmatService.spotMessage(
            log: log, frequencyMHz: "14.285", mode: "SSB", comment: nil
        )
        XCTAssertEqual(result, "SotaPostSpot AB1CD W4C/CM-001 14.285 SSB")
    }
}
