import XCTest
@testable import SOTALog

final class QSOEntryViewModelTests: XCTestCase {

    private var db: AppDatabase!
    private var log: Log!

    override func setUp() async throws {
        db = try AppDatabase.empty()
        log = try await makeLogWithId(in: db, potaRef: "US-4431", sotaRef: "W4C/CM-001")
    }

    private func makeVM() -> QSOEntryViewModel {
        QSOEntryViewModel(database: db, log: log)
    }

    // MARK: - Sensible Defaults

    func testFreshViewModelDefaults() {
        let vm = makeVM()
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.rstReceived, "599")
        XCTAssertEqual(vm.frequencyText, "14.060")
    }

    // MARK: - OmniField Parsing

    func testParseEntryAppliesRST() {
        let vm = makeVM()
        vm.entryText = "W1AW 579"
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "579")
    }

    func testParseEntryAppliesFrequency() {
        let vm = makeVM()
        vm.entryText = "W1AW 7.030"
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "7.030")
    }

    func testParseEntryAppliesQTH() {
        let vm = makeVM()
        vm.entryText = "W1AW NC"
        vm.parseEntry()
        XCTAssertEqual(vm.qth, "NC")
    }

    func testParseEntryAppliesPOTARef() {
        let vm = makeVM()
        vm.entryText = "W1AW US0001"
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "US0001")
    }

    func testParseEntryAppliesSOTARef() {
        let vm = makeVM()
        vm.entryText = "W1AW W4CCM001"
        vm.parseEntry()
        XCTAssertEqual(vm.sotaRefInput, "W4CCM001")
    }

    // MARK: - Omnifield Overrides Manual Fields

    func testOmnifieldOverridesManualFrequency() {
        let vm = makeVM()
        vm.frequencyText = "7.030"
        vm.markManualOverride("frequency")
        vm.entryText = "W1AW 14.060"
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "14.060")
    }

    func testOmnifieldOverridesManualRST() {
        let vm = makeVM()
        vm.rstSent = "559"
        vm.markManualOverride("rstSent")
        vm.entryText = "W1AW 579"
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "579")
    }

    func testOmnifieldOverridesMultipleManualFields() {
        let vm = makeVM()
        vm.frequencyText = "7.030"
        vm.rstSent = "559"
        vm.markManualOverride("frequency")
        vm.markManualOverride("rstSent")
        vm.entryText = "W1AW 579 14.060"
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "14.060")
        XCTAssertEqual(vm.rstSent, "579")
    }

    // MARK: - Save Flow

    func testSaveCreatesQSOWithCWMode() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "14.060"

        await vm.saveQSO()

        XCTAssertNotNil(vm.lastSavedQSO)
        XCTAssertEqual(vm.lastSavedQSO?.mode, "CW")
    }

    func testSaveUppercasesCallsign() async throws {
        let vm = makeVM()
        vm.entryText = "w1aw"

        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.callsign, "W1AW")
    }

    func testSaveDerivesBandFromFrequency() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "7.030"

        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.band, "40m")
    }

    func testSaveUpdatesCallsignHistory() async throws {
        let vm = makeVM()
        vm.entryText = "K3ABC"
        vm.name = "John"
        vm.qth = "PA"

        await vm.saveQSO()

        let historyRepo = CallsignHistoryRepository(database: db)
        let history = try await historyRepo.fetch(callsign: "K3ABC")
        XCTAssertEqual(history?.timesWorked, 1)
        XCTAssertEqual(history?.name, "John")
    }

    func testSaveEmptyCallsignIsNoop() async throws {
        let vm = makeVM()
        vm.entryText = ""

        await vm.saveQSO()

        XCTAssertNil(vm.lastSavedQSO)
        XCTAssertEqual(vm.saveCount, 0)
    }

    func testSaveClearsFieldsButPreservesFrequency() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "7.030"
        vm.rstSent = "579"
        vm.name = "Hiram"
        vm.qth = "CT"

        await vm.saveQSO()

        XCTAssertEqual(vm.entryText, "")
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.rstReceived, "599")
        XCTAssertEqual(vm.name, "")
        XCTAssertEqual(vm.qth, "")
        XCTAssertEqual(vm.frequencyText, "7.030") // preserved!
    }

    func testSaveIncrementsSaveCount() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"

        await vm.saveQSO()

        XCTAssertEqual(vm.saveCount, 1)
    }

    func testOverridesResetAfterSave() async throws {
        let vm = makeVM()
        vm.markManualOverride("frequency")
        vm.entryText = "W1AW"

        await vm.saveQSO()

        // After save, overrides are cleared — parseEntry should now apply frequency
        vm.entryText = "K3ABC 7.030"
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "7.030")
    }

    // MARK: - Editing Flow

    func testLoadForEditing() {
        let vm = makeVM()
        let qso = QSO(
            id: 42,
            logId: log.id!,
            callsign: "W1AW",
            date: "20240101",
            timeOn: "1234",
            frequency: 14.060,
            band: "20m",
            mode: "CW",
            rstSent: "579",
            rstReceived: "559",
            name: "Hiram",
            qth: "CT"
        )

        vm.loadForEditing(qso)

        XCTAssertTrue(vm.isEditing)
        XCTAssertEqual(vm.entryText, "W1AW")
        XCTAssertEqual(vm.rstSent, "579")
        XCTAssertEqual(vm.rstReceived, "559")
        XCTAssertEqual(vm.frequencyText, "14.060")
        XCTAssertEqual(vm.name, "Hiram")
        XCTAssertEqual(vm.qth, "CT")
    }

    func testCancelEditing() {
        let vm = makeVM()
        let qso = QSO(id: 42, logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")

        vm.loadForEditing(qso)
        XCTAssertTrue(vm.isEditing)

        vm.cancelEditing()
        XCTAssertFalse(vm.isEditing)
        XCTAssertEqual(vm.entryText, "")
    }

    func testEditPreservesOriginalDateAndTime() async throws {
        let vm = makeVM()

        // Save a QSO to the DB first
        let qsoRepo = QSORepository(database: db)
        var original = QSO(
            logId: log.id!,
            callsign: "W1AW",
            date: "20240101",
            timeOn: "1234",
            frequency: 14.060,
            band: "20m",
            mode: "CW",
            rstSent: "599",
            rstReceived: "599"
        )
        try await qsoRepo.save(&original)

        vm.loadForEditing(original)
        vm.rstSent = "579"

        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.date, "20240101")
        XCTAssertEqual(vm.lastSavedQSO?.timeOn, "1234")
        XCTAssertEqual(vm.lastSavedQSO?.rstSent, "579")
    }

    // MARK: - Spot Prefill

    func testPrefillFromSpot() {
        let vm = makeVM()
        let spot = makeSpot(
            callsign: "K3ABC",
            frequency: 7.030,
            potaReference: "US-0001",
            sotaReference: "W4C/CM-001"
        )

        vm.prefillFromSpot(spot)

        XCTAssertEqual(vm.entryText, "K3ABC")
        XCTAssertEqual(vm.frequencyText, "7.030")
        XCTAssertEqual(vm.potaRefInput, "US0001")
        XCTAssertEqual(vm.sotaRefInput, "W4CCM001")
    }

    func testPrefillClearsStaleData() {
        let vm = makeVM()
        vm.name = "Old Name"
        vm.qth = "Old QTH"
        vm.potaRefInput = "XX9999"

        let spot = makeSpot(callsign: "K3ABC", frequency: 14.060)
        vm.prefillFromSpot(spot)

        XCTAssertEqual(vm.name, "")
        XCTAssertEqual(vm.qth, "")
        XCTAssertEqual(vm.potaRefInput, "")
    }

    // MARK: - parsedCallsign

    func testParsedCallsignExtractsFirst() {
        let vm = makeVM()
        vm.entryText = "W1AW 579 14.060"
        XCTAssertEqual(vm.parsedCallsign, "W1AW")
    }

    func testParsedCallsignSanitizes() {
        let vm = makeVM()
        vm.entryText = "w1aw!!"
        XCTAssertEqual(vm.parsedCallsign, "W1AW")
    }

    func testParsedCallsignEmpty() {
        let vm = makeVM()
        vm.entryText = ""
        XCTAssertEqual(vm.parsedCallsign, "")
    }

    // MARK: - Auto-populate Cascade

    func testCallsignChangedPopulatesFromHistory() async throws {
        let historyRepo = CallsignHistoryRepository(database: db)
        try await historyRepo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)

        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.name, "Hiram")
        XCTAssertEqual(vm.qth, "CT")
        XCTAssertEqual(vm.timesWorked, 1)
    }

    func testCallsignChangedFallsBackToPrefix() async throws {
        let vm = makeVM()
        vm.entryText = "G3ABC"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.qth, "GBR")
    }

    func testSpotLookupPopulatesReferenceButNotFrequency() async throws {
        let vm = makeVM()
        vm.spotLookup = { call in
            guard call == "K3ABC" else { return nil }
            return makeSpot(callsign: "K3ABC", frequency: 7.030, potaReference: "US-0001")
        }

        vm.entryText = "K3ABC"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.frequencyText, "14.060", "Spot lookup should not override frequency")
        XCTAssertEqual(vm.potaRefInput, "US0001")
    }

    func testSpotFrequencyRespectsManualOverride() async throws {
        let vm = makeVM()
        vm.frequencyText = "14.060"
        vm.markManualOverride("frequency")

        vm.spotLookup = { call in
            guard call == "K3ABC" else { return nil }
            return makeSpot(callsign: "K3ABC", frequency: 7.030)
        }

        vm.entryText = "K3ABC"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.frequencyText, "14.060")
    }

    func testHistoryDoesNotOverwriteExistingFields() async throws {
        let historyRepo = CallsignHistoryRepository(database: db)
        try await historyRepo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)

        let vm = makeVM()
        vm.name = "Manual Name"
        vm.entryText = "W1AW"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        // History is LOW authority — should not overwrite non-empty name
        XCTAssertEqual(vm.name, "Manual Name")
        XCTAssertEqual(vm.timesWorked, 1)
    }

    func testSavePassesGridToHistory() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.name = "Hiram"
        vm.qth = "CT"

        await vm.saveQSO()

        let historyRepo = CallsignHistoryRepository(database: db)
        let history = try await historyRepo.fetch(callsign: "W1AW")
        XCTAssertEqual(history?.timesWorked, 1)
    }

    func testShortCallsignClearsLookup() async throws {
        let historyRepo = CallsignHistoryRepository(database: db)
        try await historyRepo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)

        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.callsignChanged()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(vm.name, "Hiram")

        // Now change to short callsign — clearLookupFields is synchronous for <3 chars
        vm.entryText = "W1"
        vm.callsignChanged()
        XCTAssertEqual(vm.name, "")
        XCTAssertEqual(vm.timesWorked, 0)
    }

    // MARK: - Empty Callsign Clears All Fields

    func testEmptyCallsignClearsAllFields() {
        let vm = makeVM()
        // Simulate populated state
        vm.entryText = "W1AW"
        vm.rstSent = "579"
        vm.rstReceived = "559"
        vm.name = "Hiram"
        vm.qth = "CT"
        vm.potaRefInput = "US4431"
        vm.sotaRefInput = "W4CCM001"

        // Clear callsign — empty parsedCallsign triggers clearAllFields
        vm.entryText = ""
        vm.callsignChanged()

        XCTAssertEqual(vm.rstSent, "599", "RST sent should reset to default")
        XCTAssertEqual(vm.rstReceived, "599", "RST received should reset to default")
        XCTAssertEqual(vm.name, "", "Name should be cleared")
        XCTAssertEqual(vm.qth, "", "QTH should be cleared")
        XCTAssertEqual(vm.potaRefInput, "", "POTA ref should be cleared")
        XCTAssertEqual(vm.sotaRefInput, "", "SOTA ref should be cleared")
        XCTAssertEqual(vm.timesWorked, 0, "Times worked should reset")
        XCTAssertEqual(vm.frequencyText, "14.060", "Frequency should be preserved")
    }

    func testEmptyCallsignClearsManualOverrides() {
        let vm = makeVM()
        vm.markManualOverride("frequency")
        vm.markManualOverride("qth")
        vm.entryText = "W1AW"

        // Clear callsign
        vm.entryText = ""
        vm.callsignChanged()

        // After clearing, overrides should be reset so parseEntry works freely
        vm.entryText = "K3ABC 7.030"
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "7.030", "Frequency override should be cleared after empty callsign")
    }

    func testShortCallsignDoesNotClearRST() {
        let vm = makeVM()
        vm.rstSent = "579"
        vm.rstReceived = "559"
        vm.potaRefInput = "US4431"
        vm.sotaRefInput = "W4CCM001"

        // 1-2 char callsign only clears lookup fields, not RST/refs
        vm.entryText = "W1"
        vm.callsignChanged()

        XCTAssertEqual(vm.rstSent, "579", "RST should not reset for short callsign")
        XCTAssertEqual(vm.rstReceived, "559", "RST received should not reset for short callsign")
        XCTAssertEqual(vm.potaRefInput, "US4431", "POTA ref should not clear for short callsign")
        XCTAssertEqual(vm.sotaRefInput, "W4CCM001", "SOTA ref should not clear for short callsign")
    }

    func testEmptyCallsignPreservesFrequencyAfterManualSet() {
        let vm = makeVM()
        vm.frequencyText = "7.030"
        vm.entryText = "W1AW"

        // Clear callsign
        vm.entryText = ""
        vm.callsignChanged()

        XCTAssertEqual(vm.frequencyText, "7.030", "Custom frequency should persist through clear")
    }
}
