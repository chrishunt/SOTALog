import XCTest
@testable import SOTALog

final class FlowLayoutTests: XCTestCase {

    private func rows(_ widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat = 6) -> [FlowLayout.Row] {
        FlowLayout.computeRows(
            sizes: widths.map { CGSize(width: $0, height: 20) },
            maxWidth: maxWidth,
            spacing: spacing
        )
    }

    func testAllChipsFitOneRow() {
        let result = rows([50, 50, 50], maxWidth: 200)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].range, 0..<3)
        XCTAssertEqual(result[0].width, 162, "50 + 6 + 50 + 6 + 50")
    }

    func testWrapsWhenExceedingMaxWidth() {
        // 50 + 6 + 50 = 106 > 100 — second chip wraps
        let result = rows([50, 50], maxWidth: 100)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].range, 0..<1)
        XCTAssertEqual(result[1].range, 1..<2)
    }

    func testSpacingCountsTowardWrap() {
        // Chips alone fit (48 + 48 = 96) but spacing pushes past 100
        let result = rows([48, 48], maxWidth: 100, spacing: 6)
        XCTAssertEqual(result.count, 2)
    }

    func testOversizedChipGetsOwnRow() {
        // A chip wider than the container never wraps infinitely — it takes its own row
        let result = rows([50, 300, 50], maxWidth: 100)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[1].range, 1..<2)
        XCTAssertEqual(result[1].width, 300)
    }

    func testRowHeightIsTallestChip() {
        let result = FlowLayout.computeRows(
            sizes: [CGSize(width: 40, height: 20), CGSize(width: 40, height: 32)],
            maxWidth: 200,
            spacing: 6
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].height, 32)
    }

    func testEmptyInput() {
        XCTAssertTrue(rows([], maxWidth: 100).isEmpty)
    }

    func testInfiniteWidthNeverWraps() {
        // Unspecified proposals probe with unlimited width — everything stays on one row
        let result = rows([50, 300, 500], maxWidth: .infinity)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].range, 0..<3)
    }

    func testSingleChip() {
        let result = rows([80], maxWidth: 100)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].width, 80)
    }

    func testTypicalEditModeStripFitsOneRow() {
        // time, freq, mode, rst, rst, POTA ref — representative chip widths.
        // Without dot separators the common edit-mode strip fits a 369pt line.
        let result = rows([60, 64, 36, 42, 42, 87], maxWidth: 369)
        XCTAssertEqual(result.count, 1)
    }

    func testEditModeStripWrapsOnNarrowWidths() {
        let result = rows([60, 64, 36, 42, 42, 87], maxWidth: 320)
        XCTAssertEqual(result.count, 2, "Overflow chip moves to a second row")
        XCTAssertEqual(result[0].range, 0..<5)
        XCTAssertEqual(result[1].range, 5..<6)
    }
}
