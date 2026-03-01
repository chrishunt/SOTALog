import XCTest
@testable import SOTALog

// MARK: - POTAParkService CSV Parsing

final class POTAParkCSVTests: XCTestCase {
    func testBasicCSV() {
        let csv = """
        reference,name,active,entityId,locationDesc
        US-0001,Acadia NP,1,291,Maine
        US-0002,Yellowstone NP,1,291,Wyoming
        """
        let parks = POTAParkService.parseCSV(csv)
        XCTAssertEqual(parks.count, 2)
        XCTAssertEqual(parks[0].reference, "US-0001")
        XCTAssertEqual(parks[0].name, "Acadia NP")
        XCTAssertEqual(parks[0].referenceNormalized, "US0001")
    }

    func testInactiveParksFiltered() {
        let csv = """
        reference,name,active,entityId
        US-0001,Acadia NP,1,291
        US-9999,Closed Park,0,291
        """
        let parks = POTAParkService.parseCSV(csv)
        XCTAssertEqual(parks.count, 1)
        XCTAssertEqual(parks[0].reference, "US-0001")
    }

    func testQuotedFieldsWithCommas() {
        let csv = """
        reference,name,active,entityId
        US-0001,"Acadia NP, Maine",1,291
        """
        let parks = POTAParkService.parseCSV(csv)
        XCTAssertEqual(parks.count, 1)
        XCTAssertEqual(parks[0].name, "Acadia NP, Maine")
    }

    func testEmptyCSV() {
        let parks = POTAParkService.parseCSV("")
        XCTAssertEqual(parks.count, 0)
    }

    func testHeaderOnly() {
        let csv = "reference,name,active,entityId"
        let parks = POTAParkService.parseCSV(csv)
        XCTAssertEqual(parks.count, 0)
    }

    func testWrongHeaders() {
        let csv = """
        foo,bar,baz
        US-0001,Acadia NP,1
        """
        let parks = POTAParkService.parseCSV(csv)
        XCTAssertEqual(parks.count, 0)
    }
}

// MARK: - SOTASummitService CSV Parsing

final class SOTASummitCSVTests: XCTestCase {
    func testBasicCSV() {
        let csv = """
        SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo,ActivationCount,ActivationDate,ActivationCall
        W4C/CM-001,Western Carolinas,Clingmans,Mount Mitchell,2037,6684,,,-82.265,35.765,10,0,01/04/2013,31/12/2099,100,01/01/2024,W1AW
        """
        let summits = SOTASummitService.parseCSV(csv)
        XCTAssertEqual(summits.count, 1)
        XCTAssertEqual(summits[0].code, "W4C/CM-001")
        XCTAssertEqual(summits[0].codeNormalized, "W4CCM001")
        XCTAssertEqual(summits[0].name, "Mount Mitchell")
        XCTAssertEqual(summits[0].associationCode, "W4C")
        XCTAssertEqual(summits[0].regionCode, "CM")
        XCTAssertEqual(summits[0].altitude, 2037)
        XCTAssertEqual(summits[0].points, 10)
        XCTAssertEqual(summits[0].latitude, 35.765)
        XCTAssertEqual(summits[0].longitude, -82.265)
    }

    func testCodeSplitting() {
        let csv = """
        SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo
        G/LD-001,Lake District,LD,Helvellyn,950,3117,,,-3.0,54.5,8,0,01/03/2004,
        """
        let summits = SOTASummitService.parseCSV(csv)
        XCTAssertEqual(summits.count, 1)
        XCTAssertEqual(summits[0].associationCode, "G")
        XCTAssertEqual(summits[0].regionCode, "LD")
    }

    func testEmptyCSV() {
        let summits = SOTASummitService.parseCSV("")
        XCTAssertEqual(summits.count, 0)
    }

    func testTooFewFields() {
        let csv = """
        SummitCode,Name
        W4C/CM-001,Mount Mitchell
        """
        let summits = SOTASummitService.parseCSV(csv)
        XCTAssertEqual(summits.count, 0)
    }

    func testQuotedFields() {
        let csv = """
        SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo
        W4C/CM-001,Western Carolinas,CM,"Mount Mitchell, NC",2037,6684,,,-82.265,35.765,10,0,01/04/2013,31/12/2099
        """
        let summits = SOTASummitService.parseCSV(csv)
        XCTAssertEqual(summits.count, 1)
        XCTAssertEqual(summits[0].name, "Mount Mitchell, NC")
    }

    func testValidityDates() {
        let csv = """
        SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo
        W4C/CM-001,WC,CM,Mount Mitchell,2037,6684,,,-82.265,35.765,10,0,01/04/2013,31/12/2099
        """
        let summits = SOTASummitService.parseCSV(csv)
        XCTAssertEqual(summits[0].validFrom, "01/04/2013")
        XCTAssertEqual(summits[0].validTo, "31/12/2099")
    }
}
