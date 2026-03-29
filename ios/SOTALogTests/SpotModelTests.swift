import XCTest
@testable import SOTALog

final class SpotModelTests: XCTestCase {

    // MARK: - band

    func testBandDerivesFromFrequency() {
        let spot = makeSpot(frequency: 14.060)
        XCTAssertEqual(spot.band, "20m")
    }

    func testBandFortyMeters() {
        let spot = makeSpot(frequency: 7.030)
        XCTAssertEqual(spot.band, "40m")
    }

    func testBandUnknownFrequency() {
        let spot = makeSpot(frequency: 999.0)
        XCTAssertEqual(spot.band, "?")
    }

    // MARK: - isExpired

    func testFreshSpotNotExpired() {
        let spot = makeSpot(timestamp: Date())
        XCTAssertFalse(spot.isExpired())
    }

    func testOldSpotExpired() {
        let spot = makeSpot(timestamp: Date().addingTimeInterval(-11 * 60))
        XCTAssertTrue(spot.isExpired())
    }

    func testIsExpiredCustomThreshold() {
        let spot = makeSpot(timestamp: Date().addingTimeInterval(-6 * 60))
        XCTAssertFalse(spot.isExpired(after: 10))
        XCTAssertTrue(spot.isExpired(after: 5))
    }

    // MARK: - isQRT

    func testIsQRTWithQRT() {
        let spot = makeSpot(comments: "QRT")
        XCTAssertTrue(spot.isQRT)
    }

    func testIsQRTCaseInsensitive() {
        let spot = makeSpot(comments: "going qrt now")
        XCTAssertTrue(spot.isQRT)
    }

    func testIsQRTNilComments() {
        let spot = makeSpot(comments: nil)
        XCTAssertFalse(spot.isQRT)
    }

    func testIsQRTOtherComments() {
        let spot = makeSpot(comments: "CQ CQ CQ")
        XCTAssertFalse(spot.isQRT)
    }

    // MARK: - ageMinutes

    func testAgeMinutesMinimumOne() {
        let spot = makeSpot(timestamp: Date())
        XCTAssertEqual(spot.ageMinutes, 1)
    }

    func testAgeMinutesCalculation() {
        let spot = makeSpot(timestamp: Date().addingTimeInterval(-5 * 60))
        XCTAssertEqual(spot.ageMinutes, 5)
    }

    // MARK: - sources

    func testSourcesPotaOnly() {
        let spot = makeSpot(potaReference: "US-0001")
        XCTAssertEqual(spot.sources, [.pota])
    }

    func testSourcesSotaOnly() {
        let spot = makeSpot(sotaReference: "W4C/CM-001")
        XCTAssertEqual(spot.sources, [.sota])
    }

    func testSourcesBoth() {
        let spot = makeSpot(potaReference: "US-0001", sotaReference: "W4C/CM-001")
        XCTAssertEqual(spot.sources, [.pota, .sota])
    }

    // MARK: - source (primary)

    func testSourcePrimaryPrefersPOTA() {
        let spot = makeSpot(potaReference: "US-0001", sotaReference: "W4C/CM-001")
        XCTAssertEqual(spot.source, .pota)
    }

    func testSourceFallsBackToSOTA() {
        let spot = makeSpot(sotaReference: "W4C/CM-001")
        XCTAssertEqual(spot.source, .sota)
    }

    // MARK: - reference / referenceName

    func testReferencePrefersPOTA() {
        let spot = makeSpot(potaReference: "US-0001", sotaReference: "W4C/CM-001")
        XCTAssertEqual(spot.reference, "US-0001")
    }

    func testReferenceFallsBackToSOTA() {
        let spot = makeSpot(sotaReference: "W4C/CM-001")
        XCTAssertEqual(spot.reference, "W4C/CM-001")
    }

    func testReferenceEmptyWhenNone() {
        let spot = makeSpot()
        XCTAssertEqual(spot.reference, "")
    }

    func testReferenceNamePrefersPOTA() {
        let spot = makeSpot(
            potaReference: "US-0001", potaReferenceName: "Park A",
            sotaReference: "W4C/CM-001", sotaReferenceName: "Summit B"
        )
        XCTAssertEqual(spot.referenceName, "Park A")
    }

    func testReferenceNameFallsBackToSOTA() {
        let spot = makeSpot(sotaReference: "W4C/CM-001", sotaReferenceName: "Summit B")
        XCTAssertEqual(spot.referenceName, "Summit B")
    }

    func testReferenceNameNilWhenNone() {
        let spot = makeSpot()
        XCTAssertNil(spot.referenceName)
    }
}
