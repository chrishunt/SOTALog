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

    func testManualOverridePreventsRadioSync() {
        let vm = makeVM()
        vm.markManualOverride("frequency")

        vm.updateFromRadio(frequencyMHz: 7.030)

        XCTAssertEqual(vm.frequencyText, "14.060", "Manual override should prevent radio sync")
    }

    func testOverrideResetsAfterSave() async throws {
        let vm = makeVM()
        vm.markManualOverride("frequency")
        vm.entryText = "W1AW"

        await vm.saveQSO()

        // After save, overrides are cleared — radio sync should work
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
}
