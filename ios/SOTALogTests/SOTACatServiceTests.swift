import XCTest
@testable import SOTALog

final class SOTACatServiceTests: XCTestCase {

    // MARK: - Frequency Conversion

    func testHzToMHz() {
        XCTAssertEqual(SOTACatService.hzToMHz(14_060_000), 14.060)
    }

    func testMHzToHz() {
        XCTAssertEqual(SOTACatService.mhzToHz(14.060), 14_060_000)
    }

    func testHzToMHzRounding() {
        // Verify no floating-point drift in display string
        let mhz = SOTACatService.hzToMHz(7_030_000)
        XCTAssertEqual(String(format: "%.3f", mhz), "7.030")
    }

    func testZeroFrequency() {
        XCTAssertEqual(SOTACatService.hzToMHz(0), 0.0)
        XCTAssertEqual(SOTACatService.mhzToHz(0.0), 0)
    }

    func testRoundTripConversion() {
        let originalHz = 14_060_000
        let mhz = SOTACatService.hzToMHz(originalHz)
        let backToHz = SOTACatService.mhzToHz(mhz)
        XCTAssertEqual(backToHz, originalHz)
    }

    // MARK: - VFO Sync Respects Manual Overrides

    private var db: AppDatabase!
    private var log: Log!

    override func setUp() async throws {
        db = try AppDatabase.empty()
        log = try await makeLogWithId(in: db)
    }

    private func makeVM() -> QSOEntryViewModel {
        QSOEntryViewModel(database: db, log: log)
    }

    func testRadioFrequencyUpdatesFrequencyText() {
        let vm = makeVM()
        XCTAssertEqual(vm.frequencyText, "14.060")

        vm.updateFromRadio(frequencyMHz: 7.030)

        XCTAssertEqual(vm.frequencyText, "7.030")
    }

    func testRadioSyncWorksAfterSave() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"

        await vm.saveQSO()

        vm.updateFromRadio(frequencyMHz: 7.030)
        XCTAssertEqual(vm.frequencyText, "7.030")
    }

    func testDisconnectPreservesLastFrequency() {
        let vm = makeVM()

        // Simulate radio setting frequency
        vm.updateFromRadio(frequencyMHz: 7.030)
        XCTAssertEqual(vm.frequencyText, "7.030")

        // Simulate disconnect (nil frequency) — should not change frequencyText
        vm.updateFromRadio(frequencyMHz: nil)
        XCTAssertEqual(vm.frequencyText, "7.030", "Disconnect should preserve last frequency")
    }

    func testRadioFrequencyFormatsToThreeDecimals() {
        let vm = makeVM()
        vm.updateFromRadio(frequencyMHz: SOTACatService.hzToMHz(14_062_500))
        XCTAssertEqual(vm.frequencyText, "14.062")
    }

    // MARK: - Radio Mode Sync

    func testRadioModeUpdatesMode() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")

        vm.updateModeFromRadio("SSB")
        XCTAssertEqual(vm.mode, "SSB")
    }

    func testRadioModeSyncWorksAfterSave() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"

        await vm.saveQSO()

        vm.updateModeFromRadio("CW")
        XCTAssertEqual(vm.mode, "CW")
    }

    func testDisconnectPreservesLastMode() {
        let vm = makeVM()
        vm.updateModeFromRadio("SSB")
        XCTAssertEqual(vm.mode, "SSB")

        // nil mode (disconnect) should not change mode
        vm.updateModeFromRadio(nil)
        XCTAssertEqual(vm.mode, "SSB", "Disconnect should preserve last mode")
    }

    // MARK: - Keyer URL Encoding

    func testKeyerMessageURLEncoding() {
        // Verify that messages with spaces and slashes encode properly for URL query
        let message = "CQ SOTA DE W1AW K"
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        XCTAssertTrue(encoded.contains("CQ%20SOTA"), "Spaces should be percent-encoded")
        XCTAssertFalse(encoded.contains(" "), "No literal spaces in encoded URL")

        let slashMessage = "W4C/CM-001"
        let slashEncoded = slashMessage.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        // URL should be constructable with the encoded message
        let url = URL(string: "http://sotacat.local/api/v1/keyer?message=\(slashEncoded)")
        XCTAssertNotNil(url, "URL with encoded slash message should be valid")
    }
}
