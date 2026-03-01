import XCTest
@testable import SOTALog

final class DateFormattingTests: XCTestCase {
    func testAdifDate() {
        let date = makeUTCDate(year: 2024, month: 6, day: 15)
        XCTAssertEqual(date.adifDate, "20240615")
    }

    func testAdifTime() {
        let date = makeUTCDate(hour: 14, minute: 30)
        XCTAssertEqual(date.adifTime, "1430")
    }

    func testUtcTimeDisplay() {
        let date = makeUTCDate(hour: 14, minute: 30)
        XCTAssertEqual(date.utcTimeDisplay, "14:30Z")
    }

    func testShortDateDisplay() {
        let date = makeUTCDate(year: 2024, month: 6, day: 15)
        XCTAssertEqual(date.shortDateDisplay, "2024-06-15")
    }

    func testMidnightTime() {
        let date = makeUTCDate(hour: 0, minute: 0)
        XCTAssertEqual(date.adifTime, "0000")
    }

    func testEndOfDayTime() {
        let date = makeUTCDate(hour: 23, minute: 59)
        XCTAssertEqual(date.adifTime, "2359")
    }
}
