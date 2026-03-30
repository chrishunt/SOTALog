import XCTest
@testable import SOTALog

final class SyncImporterTests: XCTestCase {

    // Shared validation dictionaries for tests
    let validPotaRefs: [String: String] = [
        "US4431": "US-4431",
        "US0001": "US-0001",
        "US0002": "US-0002",
    ]

    let validSotaCodes: [String: String] = [
        "W4CCM001": "W4C/CM-001",
        "GLD001": "G/LD-001",
    ]

    // MARK: - Single POTA Activation

    func testSinglePOTAActivation() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
                "STATION_CALLSIGN": "W1AW",
            ],
            [
                "CALL": "N4XYZ",
                "QSO_DATE": "20240315",
                "TIME_ON": "1205",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
                "STATION_CALLSIGN": "W1AW",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].qsos.count, 2)
        XCTAssertEqual(result.activations[0].key.potaReference, "US-4431")
        XCTAssertNil(result.activations[0].key.sotaReference)
        XCTAssertEqual(result.unattached.count, 0)
    }

    // MARK: - Two Activations Same Day, Different Refs

    func testTwoActivationsSameDay() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
                "STATION_CALLSIGN": "W1AW",
            ],
            [
                "CALL": "N4XYZ",
                "QSO_DATE": "20240315",
                "TIME_ON": "1400",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-0001",
                "STATION_CALLSIGN": "W1AW",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 2)
        XCTAssertEqual(result.activations[0].qsos.count, 1)
        XCTAssertEqual(result.activations[1].qsos.count, 1)
    }

    // MARK: - SOTA-Only Activation

    func testSOTAOnlyActivation() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SOTA_REF": "W4C/CM-001",
                "STATION_CALLSIGN": "W1AW",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].key.sotaReference, "W4C/CM-001")
        XCTAssertNil(result.activations[0].key.potaReference)
    }

    // MARK: - Dual Activation (POTA + SOTA)

    func testDualActivation() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
                "MY_SOTA_REF": "W4C/CM-001",
                "STATION_CALLSIGN": "W1AW",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].key.potaReference, "US-4431")
        XCTAssertEqual(result.activations[0].key.sotaReference, "W4C/CM-001")
    }

    // MARK: - No-Ref QSOs Go Unattached

    func testNoRefQSOsAreUnattached() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "STATION_CALLSIGN": "W1AW",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 0)
        XCTAssertEqual(result.unattached.count, 1)
    }

    // MARK: - Mixed Refs and No-Refs

    func testMixedRefsAndNoRefs() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
            ],
            [
                "CALL": "N4XYZ",
                "QSO_DATE": "20240315",
                "TIME_ON": "1205",
                "BAND": "20m",
                "MODE": "CW",
                // No ref
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.unattached.count, 1)
    }

    // MARK: - Fallback Callsign

    func testFallbackCallsignWhenMissing() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
                // No STATION_CALLSIGN
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "KI5LHR",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations[0].key.stationCallsign, "KI5LHR")
    }

    // MARK: - Different Days, Same Ref = Separate Activations

    func testDifferentDaysSameRefAreSeparate() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
            ],
            [
                "CALL": "N4XYZ",
                "QSO_DATE": "20240316",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 2)
    }

    // MARK: - Invalid POTA Ref → Unattached

    func testInvalidPotaRefTreatedAsUnattached() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "XX-9999",  // not in validPotaRefs
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 0)
        XCTAssertEqual(result.unattached.count, 1)
    }

    // MARK: - Invalid SOTA Ref → Unattached

    func testInvalidSotaRefTreatedAsUnattached() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SOTA_REF": "XX/YY-999",  // not in validSotaCodes
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 0)
        XCTAssertEqual(result.unattached.count, 1)
    }

    // MARK: - Valid POTA + Invalid SOTA → Activation With Only POTA

    func testValidPotaInvalidSotaOnlyPotaRef() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",
                "MY_SOTA_REF": "XX/YY-999",  // invalid
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].key.potaReference, "US-4431")
        XCTAssertNil(result.activations[0].key.sotaReference)
    }

    // MARK: - MY_SIG_INFO Without MY_SIG Still Treated as POTA Ref

    func testMySigInfoWithoutMySigStillValidated() {
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US-4431",  // No MY_SIG field
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].key.potaReference, "US-4431")
    }

    // MARK: - Normalized POTA Ref Lookup

    func testNormalizedPotaRefLookup() {
        // QRZ sometimes sends "US4431" without the dash
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SIG_INFO": "US4431",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].key.potaReference, "US-4431")
    }

    // MARK: - Normalized SOTA Ref Lookup

    func testNormalizedSotaRefLookup() {
        // QRZ might strip formatting
        let records: [[String: String]] = [
            [
                "CALL": "K3ABC",
                "QSO_DATE": "20240315",
                "TIME_ON": "1200",
                "BAND": "20m",
                "MODE": "CW",
                "MY_SOTA_REF": "W4CCM001",
            ],
        ]

        let result = SyncImporter.groupByActivation(
            records: records,
            fallbackCallsign: "W1AW",
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        XCTAssertEqual(result.activations.count, 1)
        XCTAssertEqual(result.activations[0].key.sotaReference, "W4C/CM-001")
    }
}
