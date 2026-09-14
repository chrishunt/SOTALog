import XCTest
@testable import SOTALog

final class SanitizedOmnifieldTests: XCTestCase {
    func testUppercases() {
        XCTAssertEqual("w1aw 579".sanitizedOmnifield, "W1AW 579")
    }

    func testPreservesAllowedCharacters() {
        XCTAssertEqual("W1AW/P 14.060 NC-VA".sanitizedOmnifield, "W1AW/P 14.060 NC-VA")
    }

    func testStripsSpecialCharacters() {
        XCTAssertEqual("W1AW!@# 579".sanitizedOmnifield, "W1AW 579")
    }

    func testEmptyString() {
        XCTAssertEqual("".sanitizedOmnifield, "")
    }
}
