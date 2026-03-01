import XCTest
@testable import SOTALog

final class SpotsViewModelTests: XCTestCase {

    // MARK: - Consolidation

    func testTwoSpotsForSameCallsignKeepsNewest() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now.addingTimeInterval(-60)),
            makeSpot(id: "2", callsign: "W1AW", frequency: 14.062, potaReference: "US-0002", timestamp: now),
        ]

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].potaReference, "US-0002")
    }

    func testConsolidationMergesPOTAAndSOTA() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now),
            makeSpot(id: "2", callsign: "W1AW", frequency: 14.060, sotaReference: "W4C/CM-001", timestamp: now.addingTimeInterval(-30)),
        ]

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 1)
        XCTAssertNotNil(all[0].potaReference)
        XCTAssertNotNil(all[0].sotaReference)
    }

    func testNewerReferenceWinsForSameType() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0002", timestamp: now),
            makeSpot(id: "2", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now.addingTimeInterval(-60)),
        ]

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].potaReference, "US-0002")
    }

    // MARK: - spotsByBand

    func testSpotsByBandGroupsByBand() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now),
            makeSpot(id: "2", callsign: "K3ABC", frequency: 7.030, potaReference: "US-0002", timestamp: now),
        ]

        let bands = vm.spotsByBand
        XCTAssertEqual(bands.count, 2)
    }

    func testSpotsSortedByFrequencyWithinBand() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "K3ABC", frequency: 14.070, potaReference: "US-0002", timestamp: now),
            makeSpot(id: "2", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now),
        ]

        let twentyM = vm.spotsByBand.first(where: { $0.band == "20m" })!
        XCTAssertEqual(twentyM.spots[0].frequency, 14.060)
        XCTAssertEqual(twentyM.spots[1].frequency, 14.070)
    }

    func testExpiredSpotsExcluded() {
        let vm = SpotsViewModel()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: Date().addingTimeInterval(-11 * 60)),
        ]

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 0)
    }

    func testQRTSpotsExcluded() {
        let vm = SpotsViewModel()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", comments: "QRT"),
        ]

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 0)
    }

    func testBandOrderingFollowsBandPlan() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "K3ABC", frequency: 14.060, potaReference: "US-0001", timestamp: now),
            makeSpot(id: "2", callsign: "W1AW", frequency: 7.030, potaReference: "US-0002", timestamp: now),
            makeSpot(id: "3", callsign: "N4XYZ", frequency: 21.060, potaReference: "US-0003", timestamp: now),
        ]

        let bandNames = vm.spotsByBand.map(\.band)
        XCTAssertEqual(bandNames, ["40m", "20m", "15m"])
    }

    // MARK: - Source Filtering

    func testPOTAFilterExcludesSOTAOnly() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now),
            makeSpot(id: "2", callsign: "K3ABC", frequency: 14.062, sotaReference: "W4C/CM-001", timestamp: now),
        ]
        vm.sourceFilter = .pota

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].activatorCallsign, "W1AW")
    }

    func testSOTAFilterExcludesPOTAOnly() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now),
            makeSpot(id: "2", callsign: "K3ABC", frequency: 14.062, sotaReference: "W4C/CM-001", timestamp: now),
        ]
        vm.sourceFilter = .sota

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].activatorCallsign, "K3ABC")
    }

    func testAllFilterShowsEverything() {
        let vm = SpotsViewModel()
        let now = Date()

        vm.spots = [
            makeSpot(id: "1", callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: now),
            makeSpot(id: "2", callsign: "K3ABC", frequency: 14.062, sotaReference: "W4C/CM-001", timestamp: now),
        ]
        vm.sourceFilter = .all

        let all = vm.spotsByBand.flatMap(\.spots)
        XCTAssertEqual(all.count, 2)
    }

    // MARK: - spotForCallsign

    func testSpotForCallsignFound() {
        let vm = SpotsViewModel()
        vm.spots = [
            makeSpot(callsign: "W1AW", frequency: 14.060, potaReference: "US-0001"),
        ]

        let spot = vm.spotForCallsign("W1AW")
        XCTAssertNotNil(spot)
        XCTAssertEqual(spot?.potaReference, "US-0001")
    }

    func testSpotForCallsignCaseInsensitive() {
        let vm = SpotsViewModel()
        vm.spots = [
            makeSpot(callsign: "W1AW", frequency: 14.060, potaReference: "US-0001"),
        ]

        let spot = vm.spotForCallsign("w1aw")
        XCTAssertNotNil(spot)
    }

    func testSpotForCallsignExcludesExpired() {
        let vm = SpotsViewModel()
        vm.spots = [
            makeSpot(callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", timestamp: Date().addingTimeInterval(-11 * 60)),
        ]

        let spot = vm.spotForCallsign("W1AW")
        XCTAssertNil(spot)
    }

    func testSpotForCallsignExcludesQRT() {
        let vm = SpotsViewModel()
        vm.spots = [
            makeSpot(callsign: "W1AW", frequency: 14.060, potaReference: "US-0001", comments: "QRT"),
        ]

        let spot = vm.spotForCallsign("W1AW")
        XCTAssertNil(spot)
    }

    func testSpotForCallsignUnknown() {
        let vm = SpotsViewModel()
        vm.spots = [
            makeSpot(callsign: "W1AW", frequency: 14.060, potaReference: "US-0001"),
        ]

        let spot = vm.spotForCallsign("XX9ZZZ")
        XCTAssertNil(spot)
    }
}
