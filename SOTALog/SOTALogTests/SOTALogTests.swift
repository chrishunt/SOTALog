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
        XCTAssertEqual(BandPlan.band(for: 144.060), "2m")
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

    // MARK: - Mode Derivation

    func testModeCWSubBand() {
        XCTAssertEqual(BandPlan.mode(for: 14.060), "CW")
        XCTAssertEqual(BandPlan.mode(for: 7.030), "CW")
        XCTAssertEqual(BandPlan.mode(for: 3.530), "CW")
        XCTAssertEqual(BandPlan.mode(for: 21.060), "CW")
    }

    func testModeSSBSubBand() {
        XCTAssertEqual(BandPlan.mode(for: 14.260), "SSB")
        XCTAssertEqual(BandPlan.mode(for: 7.200), "SSB")
        XCTAssertEqual(BandPlan.mode(for: 3.860), "SSB")
        XCTAssertEqual(BandPlan.mode(for: 21.300), "SSB")
    }

    func testModeBoundary() {
        // At the SSB boundary frequency, mode is SSB
        XCTAssertEqual(BandPlan.mode(for: 14.150), "SSB")
        // Just below the boundary is CW
        XCTAssertEqual(BandPlan.mode(for: 14.149), "CW")
    }

    func testModeCWOnlyBands() {
        XCTAssertEqual(BandPlan.mode(for: 10.110), "CW")  // 30m
        XCTAssertEqual(BandPlan.mode(for: 5.332), "CW")   // 60m
    }

    func testModeOutOfBand() {
        XCTAssertNil(BandPlan.mode(for: 0.5))
        XCTAssertNil(BandPlan.mode(for: 100.0))
    }

    func testDefaultSSBFrequencies() {
        // SSB-capable bands have defaults
        XCTAssertNotNil(BandPlan.defaultSSBFrequency(for: "20m"))
        XCTAssertNotNil(BandPlan.defaultSSBFrequency(for: "40m"))

        // CW-only bands return nil
        XCTAssertNil(BandPlan.defaultSSBFrequency(for: "30m"))
        XCTAssertNil(BandPlan.defaultSSBFrequency(for: "60m"))
    }

    func testDefaultSSBFrequenciesAreWithinBand() {
        for bandName in BandPlan.allBands {
            if let freq = BandPlan.defaultSSBFrequency(for: bandName) {
                XCTAssertEqual(BandPlan.band(for: freq), bandName)
                XCTAssertEqual(BandPlan.mode(for: freq), "SSB")
            }
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
    func testUSCallsignSingleState() {
        XCTAssertEqual(CallsignPrefixResolver.resolve("K6ABC"), "CA")
    }

    func testUSCallsignMultiStateReturnsNil() {
        XCTAssertNil(CallsignPrefixResolver.resolve("W1AW"))   // district 1 = CT/MA/ME/...
        XCTAssertNil(CallsignPrefixResolver.resolve("N4XYZ"))  // district 4 = AL/FL/GA/...
        XCTAssertNil(CallsignPrefixResolver.resolve("AA1BB"))  // district 1
    }

    func testCanadianCallsigns() {
        XCTAssertEqual(CallsignPrefixResolver.resolve("VE3ABC"), "ON")
        XCTAssertEqual(CallsignPrefixResolver.resolve("VA7XYZ"), "BC")
        XCTAssertEqual(CallsignPrefixResolver.resolve("VE1QQ"), "NS")
    }

    func testDXCallsigns() {
        XCTAssertEqual(CallsignPrefixResolver.resolve("G3ABC"), "GBR")
        XCTAssertEqual(CallsignPrefixResolver.resolve("DL1XYZ"), "DEU")
        XCTAssertEqual(CallsignPrefixResolver.resolve("JA1ABC"), "JPN")
        XCTAssertEqual(CallsignPrefixResolver.resolve("VK2ABC"), "AUS")
    }

    func testShortCallsigns() {
        XCTAssertNil(CallsignPrefixResolver.resolve("A"))
        XCTAssertNil(CallsignPrefixResolver.resolve(""))
    }

    func testAbbreviateKnownCountries() {
        XCTAssertEqual(CallsignPrefixResolver.abbreviate("Japan"), "JPN")
        XCTAssertEqual(CallsignPrefixResolver.abbreviate("Germany"), "DEU")
        XCTAssertEqual(CallsignPrefixResolver.abbreviate("England"), "GBR")
        XCTAssertEqual(CallsignPrefixResolver.abbreviate("Australia"), "AUS")
    }

    func testAbbreviateUnknownCountryPassthrough() {
        XCTAssertEqual(CallsignPrefixResolver.abbreviate("Tonga"), "Tonga")
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

    func testEncodeFileWithLogContext() {
        let qso = QSO(logId: 1, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        let log = Log(myCallsign: "K3ABC", myGrid: "FN20", potaReference: "US-4431", parkName: "Prescott NF")
        let adif = ADIFFormatter.encodeFile(sections: [(log, [qso])])
        XCTAssertTrue(adif.contains("<STATION_CALLSIGN:5>K3ABC"))
        XCTAssertTrue(adif.contains("<MY_SIG:4>POTA"))
        XCTAssertTrue(adif.contains("<MY_SIG_INFO:7>US-4431"))
        XCTAssertTrue(adif.contains("<MY_GRIDSQUARE:4>FN20"))
    }

    func testEncodeFileMultipleLogSections() {
        let qso1 = QSO(logId: 1, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        let log1 = Log(myCallsign: "K3ABC", potaReference: "US-4431", parkName: "Prescott NF")

        let qso2 = QSO(logId: 2, callsign: "VE3XYZ", date: "20240102", timeOn: "0800", band: "40m")
        let log2 = Log(myCallsign: "K3ABC", sotaReference: "W4C/CM-001", summitName: "Mt Mitchell")

        let adif = ADIFFormatter.encodeFile(sections: [(log1, [qso1]), (log2, [qso2])])

        // Only one header
        let eohCount = adif.components(separatedBy: "<EOH>").count - 1
        XCTAssertEqual(eohCount, 1)

        // First QSO gets POTA fields
        XCTAssertTrue(adif.contains("<MY_SIG:4>POTA"))
        XCTAssertTrue(adif.contains("<MY_SIG_INFO:7>US-4431"))

        // Second QSO gets SOTA field
        XCTAssertTrue(adif.contains("<MY_SOTA_REF:10>W4C/CM-001"))

        // Both QSOs present
        XCTAssertTrue(adif.contains("<CALL:4>W1AW"))
        XCTAssertTrue(adif.contains("<CALL:6>VE3XYZ"))
    }

    func testEncodeFileWithoutLogContextOmitsLogFields() {
        let qso = QSO(logId: 1, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        let adif = ADIFFormatter.encodeFile(qsos: [qso])
        XCTAssertFalse(adif.contains("STATION_CALLSIGN"))
        XCTAssertFalse(adif.contains("MY_SIG"))
        XCTAssertFalse(adif.contains("MY_GRIDSQUARE"))
        XCTAssertFalse(adif.contains("MY_SOTA_REF"))
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

// MARK: - ADIFFormatter Program Filtering Tests

final class ADIFFormatterProgramFilterTests: XCTestCase {
    private let dualLog = Log(
        myCallsign: "W1AW",
        myGrid: "FN31",
        potaReference: "US-4431",
        sotaReference: "W4C/CM-001",
        parkName: "Prescott NF",
        summitName: "Mt Mitchell"
    )

    private func makeDualQSO() -> QSO {
        QSO(
            logId: 1,
            callsign: "K3ABC",
            date: "20240315",
            timeOn: "1200",
            band: "20m",
            mode: "CW",
            rstSent: "599",
            rstReceived: "579",
            sotaRef: "W4C/CM-002",
            potaRef: "US-0001"
        )
    }

    func testPOTAExportStripsSOTAFields() {
        let adif = ADIFFormatter.encode(qso: makeDualQSO(), log: dualLog, program: .pota)
        XCTAssertFalse(adif.contains("MY_SOTA_REF"))
        XCTAssertFalse(adif.contains("SOTA_REF"))
        // POTA fields present
        XCTAssertTrue(adif.contains("MY_SIG"))
        XCTAssertTrue(adif.contains("MY_SIG_INFO"))
    }

    func testSOTAExportStripsPOTAFields() {
        let adif = ADIFFormatter.encode(qso: makeDualQSO(), log: dualLog, program: .sota)
        XCTAssertFalse(adif.contains("MY_SIG"))
        XCTAssertFalse(adif.contains("MY_SIG_INFO"))
        XCTAssertFalse(adif.contains("<SIG:"))
        XCTAssertFalse(adif.contains("SIG_INFO"))
        // SOTA fields present
        XCTAssertTrue(adif.contains("MY_SOTA_REF"))
        XCTAssertTrue(adif.contains("SOTA_REF"))
    }

    func testUnfilteredIncludesAllFields() {
        let adif = ADIFFormatter.encode(qso: makeDualQSO(), log: dualLog, program: nil)
        XCTAssertTrue(adif.contains("MY_SIG"))
        XCTAssertTrue(adif.contains("MY_SIG_INFO"))
        XCTAssertTrue(adif.contains("MY_SOTA_REF"))
        XCTAssertTrue(adif.contains("SOTA_REF"))
        XCTAssertTrue(adif.contains("SIG_INFO"))
    }

    func testP2PPreservedInPOTAExport() {
        let qso = QSO(logId: 1, callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m", potaRef: "US-0001")
        let log = Log(myCallsign: "W1AW", potaReference: "US-4431", parkName: "Prescott NF")
        let adif = ADIFFormatter.encode(qso: qso, log: log, program: .pota)
        XCTAssertTrue(adif.contains("<SIG:4>POTA"))
        XCTAssertTrue(adif.contains("<SIG_INFO:7>US-0001"))
    }

    func testS2SPreservedInSOTAExport() {
        let qso = QSO(logId: 1, callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m", sotaRef: "W4C/CM-002")
        let log = Log(myCallsign: "W1AW", sotaReference: "W4C/CM-001", summitName: "Mt Mitchell")
        let adif = ADIFFormatter.encode(qso: qso, log: log, program: .sota)
        XCTAssertTrue(adif.contains("<SOTA_REF:10>W4C/CM-002"))
        XCTAssertTrue(adif.contains("<MY_SOTA_REF:10>W4C/CM-001"))
    }

    func testCrossProgramRefsExcluded() {
        // SOTA ref in POTA export → no SOTA_REF
        let qsoWithSOTA = QSO(logId: 1, callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m", sotaRef: "W4C/CM-002")
        let potaLog = Log(myCallsign: "W1AW", potaReference: "US-4431", parkName: "Prescott NF")
        let potaADIF = ADIFFormatter.encode(qso: qsoWithSOTA, log: potaLog, program: .pota)
        XCTAssertFalse(potaADIF.contains("SOTA_REF"))

        // POTA ref in SOTA export → no SIG/SIG_INFO
        let qsoWithPOTA = QSO(logId: 1, callsign: "K3ABC", date: "20240315", timeOn: "1200", band: "20m", potaRef: "US-0001")
        let sotaLog = Log(myCallsign: "W1AW", sotaReference: "W4C/CM-001", summitName: "Mt Mitchell")
        let sotaADIF = ADIFFormatter.encode(qso: qsoWithPOTA, log: sotaLog, program: .sota)
        XCTAssertFalse(sotaADIF.contains("<SIG:"))
        XCTAssertFalse(sotaADIF.contains("SIG_INFO"))
    }

    func testFilenameGeneration() {
        let potaLog = Log(date: "20240315", myCallsign: "W1AW", potaReference: "US-4431", parkName: "Prescott NF")
        XCTAssertEqual(
            ADIFFormatter.filename(log: potaLog, program: .pota),
            "W1AW@US-4431_20240315.adi"
        )

        let sotaLog = Log(date: "20240315", myCallsign: "W1AW", sotaReference: "W4C/CM-001", summitName: "Mt Mitchell")
        XCTAssertEqual(
            ADIFFormatter.filename(log: sotaLog, program: .sota),
            "W1AW@W4C-CM-001_20240315.adi"
        )

        // Chaser filename (no SOTA ref on log)
        let chaserLog = Log(date: "20240315", myCallsign: "W1AW")
        XCTAssertEqual(
            ADIFFormatter.filename(log: chaserLog, program: .sota),
            "W1AW_SOTA_20240315.adi"
        )

        // Complete filename
        XCTAssertEqual(
            ADIFFormatter.filename(log: potaLog, program: nil),
            "W1AW_20240315.adi"
        )
    }
}

// MARK: - ADIFFormatter QRZ Field Parsing

final class ADIFFormatterQRZFieldTests: XCTestCase {
    func testDecodePreservesAppQRZLogLogId() {
        let adif = "<CALL:4>W1AW<QSO_DATE:8>20240101<TIME_ON:4>1200<BAND:3>20m<APP_QRZLOG_LOGID:6>123456<EOR>"
        let records = ADIFFormatter.decode(adif)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0]["APP_QRZLOG_LOGID"], "123456")
    }

    func testDecodeUppercasesFieldNames() {
        let adif = "<call:4>W1AW<qso_date:8>20240101<time_on:4>1200<band:3>20m<app_qrzlog_logid:3>100<EOR>"
        let records = ADIFFormatter.decode(adif)
        XCTAssertEqual(records[0]["CALL"], "W1AW")
        XCTAssertEqual(records[0]["APP_QRZLOG_LOGID"], "100")
    }
}

// MARK: - QRZLogbookService Response Parsing

final class QRZResponseParsingTests: XCTestCase {
    func testParseResponseExtractsHTMLEncodedADIF() {
        // QRZ FETCH response: ADIF blob is HTML-encoded (&lt; &gt;)
        let response = "RESULT=OK&COUNT=2&ADIF=&lt;call:4&gt;W1AW&lt;app_qrzlog_logid:3&gt;100&lt;eor&gt;\n&lt;call:5&gt;K3ABC&lt;app_qrzlog_logid:3&gt;200&lt;eor&gt;"
        let parsed = QRZLogbookService.parseResponse(response)

        XCTAssertEqual(parsed["RESULT"], "OK")
        XCTAssertEqual(parsed["COUNT"], "2")
        XCTAssertNotNil(parsed["ADIF"])

        // Decode requires unescaping first (done by downloadQSOs)
        let adif = parsed["ADIF"]!
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
        let records = ADIFFormatter.decode(adif)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0]["APP_QRZLOG_LOGID"], "100")
        XCTAssertEqual(records[1]["APP_QRZLOG_LOGID"], "200")
    }

    func testParseResponseNoADIF() {
        let response = "RESULT=OK&LOGID=12345&COUNT=1"
        let parsed = QRZLogbookService.parseResponse(response)
        XCTAssertEqual(parsed["RESULT"], "OK")
        XCTAssertEqual(parsed["LOGID"], "12345")
        XCTAssertEqual(parsed["COUNT"], "1")
        XCTAssertNil(parsed["ADIF"])
    }

    func testParseResponseFailure() {
        let response = "RESULT=FAIL&REASON=invalid api key"
        let parsed = QRZLogbookService.parseResponse(response)
        XCTAssertEqual(parsed["RESULT"], "FAIL")
        XCTAssertEqual(parsed["REASON"], "invalid api key")
    }
}

// MARK: - QRZLogbookService Form Encoding

final class QRZFormEncodingTests: XCTestCase {
    func testFormSafeCharactersExcludeReserved() {
        // Characters like &, =, + must be percent-encoded in form data
        let testValue = "KEY=value&other+stuff"
        let safe: CharacterSet = {
            var cs = CharacterSet.alphanumerics
            cs.insert(charactersIn: "-._~")
            return cs
        }()
        let encoded = testValue.addingPercentEncoding(withAllowedCharacters: safe)!
        XCTAssertFalse(encoded.contains("&"))
        XCTAssertFalse(encoded.contains("="))
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertTrue(encoded.contains("%26"))  // & encoded
        XCTAssertTrue(encoded.contains("%3D"))  // = encoded
        XCTAssertTrue(encoded.contains("%2B"))  // + encoded
    }

    func testFormSafeCharactersAllowAlphanumerics() {
        let safe: CharacterSet = {
            var cs = CharacterSet.alphanumerics
            cs.insert(charactersIn: "-._~")
            return cs
        }()
        let simple = "W1AW"
        let encoded = simple.addingPercentEncoding(withAllowedCharacters: safe)!
        XCTAssertEqual(encoded, "W1AW")
    }

    func testADIFContentEncodedProperly() {
        // ADIF records contain <> which must be percent-encoded
        let adif = "<CALL:4>W1AW<EOR>"
        let safe: CharacterSet = {
            var cs = CharacterSet.alphanumerics
            cs.insert(charactersIn: "-._~")
            return cs
        }()
        let encoded = adif.addingPercentEncoding(withAllowedCharacters: safe)!
        XCTAssertFalse(encoded.contains("<"))
        XCTAssertFalse(encoded.contains(">"))
        XCTAssertFalse(encoded.contains(":"))
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

// MARK: - OmniFieldParser Tests

final class OmniFieldParserTests: XCTestCase {
    func testCallsignOnly() {
        let result = OmniFieldParser.parse("W1AW")
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertNil(result.rstSent)
        XCTAssertNil(result.rstReceived)
        XCTAssertNil(result.frequency)
        XCTAssertNil(result.qth)
        XCTAssertNil(result.potaRef)
        XCTAssertNil(result.sotaRef)
    }

    func testFullEntry() {
        let result = OmniFieldParser.parse("W1AW 579 559 14.060 CT")
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertEqual(result.rstSent, "579")
        XCTAssertEqual(result.rstReceived, "559")
        XCTAssertEqual(result.frequency, "14.060")
        XCTAssertEqual(result.qth, "CT")
    }

    func testTwoDigitRSTRawValue() {
        let result = OmniFieldParser.parse("K3ABC 55")
        XCTAssertEqual(result.callsign, "K3ABC")
        XCTAssertEqual(result.rstSent, "55")
    }

    func testThreeDigitRST() {
        let result = OmniFieldParser.parse("K3ABC 579")
        XCTAssertEqual(result.rstSent, "579")
    }

    func testTwoRSTValues() {
        let result = OmniFieldParser.parse("W1AW 579 339")
        XCTAssertEqual(result.rstSent, "579")
        XCTAssertEqual(result.rstReceived, "339")
    }

    func testPOTARef() {
        let result = OmniFieldParser.parse("W1AW US4431")
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertEqual(result.potaRef, "US4431")
    }

    func testSOTARef() {
        let result = OmniFieldParser.parse("W1AW W4CCM001")
        XCTAssertEqual(result.callsign, "W1AW")
        XCTAssertEqual(result.sotaRef, "W4CCM001")
    }

    func testFrequencyDetection() {
        let result = OmniFieldParser.parse("W1AW 7.030")
        XCTAssertEqual(result.frequency, "7.030")
    }

    func testQTHDetection() {
        let result = OmniFieldParser.parse("W1AW NC")
        XCTAssertEqual(result.qth, "NC")
    }

    func testUnrecognizedTokensIgnored() {
        let result = OmniFieldParser.parse("W1AW XYZZY")
        XCTAssertEqual(result.callsign, "W1AW")
        // XYZZY doesn't match any pattern — silently ignored
    }

    func testModeTokenCW() {
        let result = OmniFieldParser.parse("W1AW CW")
        XCTAssertEqual(result.mode, "CW")
    }

    func testModeTokenSSB() {
        let result = OmniFieldParser.parse("W1AW SSB")
        XCTAssertEqual(result.mode, "SSB")
    }

    func testModeTokenCaseInsensitive() {
        let result = OmniFieldParser.parse("W1AW ssb")
        XCTAssertEqual(result.mode, "SSB")
    }

    func testModeTokenConsumed() {
        let result = OmniFieldParser.parse("W1AW SSB")
        XCTAssertEqual(result.tokens.count, 2)
        XCTAssertEqual(result.tokens[1].kind, .mode)
    }

    func testModeTokenWithOtherTokens() {
        let result = OmniFieldParser.parse("W1AW SSB 59 14.260")
        XCTAssertEqual(result.mode, "SSB")
        XCTAssertEqual(result.rstSent, "59")
        XCTAssertEqual(result.frequency, "14.260")
    }

    func testEmptyInput() {
        let result = OmniFieldParser.parse("")
        XCTAssertEqual(result.callsign, "")
    }

    func testCanadianQTH() {
        let result = OmniFieldParser.parse("VE3ABC ON")
        XCTAssertEqual(result.qth, "ON")
    }

    func testInvalidRSTIgnored() {
        // "69" has R=6 which is out of 1-5 range
        let result = OmniFieldParser.parse("W1AW 69")
        XCTAssertNil(result.rstSent)
    }

    func testCombinedRSTAndFrequency() {
        let result = OmniFieldParser.parse("W1AW 57 14.060")
        XCTAssertEqual(result.rstSent, "57")
        XCTAssertEqual(result.frequency, "14.060")
    }
}

// MARK: - Log Model Tests

final class LogModelTests: XCTestCase {
    func testFormattedDate() {
        let log = Log(date: "20240315", myCallsign: "W1AW")
        XCTAssertEqual(log.formattedDate, "2024-03-15")
    }

    func testFormattedDateShortString() {
        let log = Log(date: "202", myCallsign: "W1AW")
        XCTAssertEqual(log.formattedDate, "202")
    }

    func testFormattedDateEmpty() {
        let log = Log(date: "", myCallsign: "W1AW")
        XCTAssertEqual(log.formattedDate, "")
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
        var log = Log(date: "20240101", myCallsign: "W1AW")
        try await logRepo.save(&log)
        XCTAssertNotNil(log.id)

        // Read
        let fetched = try await logRepo.fetch(id: log.id!)
        XCTAssertEqual(fetched?.myCallsign, "W1AW")

        // Delete
        try await logRepo.delete(id: log.id!)
        let deleted = try await logRepo.fetch(id: log.id!)
        XCTAssertNil(deleted)
    }

    func testQSOCRUD() async throws {
        let db = try AppDatabase.empty()
        let logRepo = LogRepository(database: db)
        let qsoRepo = QSORepository(database: db)

        var log = Log(date: "20240101", myCallsign: "W1AW")
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

}
