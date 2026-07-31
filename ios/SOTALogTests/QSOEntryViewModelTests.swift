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

    func testSaveCreatesQSOWithSSBMode() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "14.260"
        vm.mode = "SSB"
        vm.rstSent = "59"
        vm.rstReceived = "59"

        await vm.saveQSO()

        XCTAssertNotNil(vm.lastSavedQSO)
        XCTAssertEqual(vm.lastSavedQSO?.mode, "SSB")
        XCTAssertEqual(vm.lastSavedQSO?.rstSent, "59")
    }

    func testSaveCreatesQSOWithFMMode() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "146.520"
        vm.mode = "FM"
        vm.rstSent = "59"
        vm.rstReceived = "59"

        await vm.saveQSO()

        XCTAssertNotNil(vm.lastSavedQSO)
        XCTAssertEqual(vm.lastSavedQSO?.mode, "FM")
        XCTAssertEqual(vm.lastSavedQSO?.band, "2m")
        XCTAssertEqual(vm.lastSavedQSO?.rstSent, "59")
    }

    func testModeAutoDerivesToFMOn2m() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")

        vm.frequencyText = "146.520"
        vm.frequencyChanged()
        XCTAssertEqual(vm.mode, "FM")
        XCTAssertEqual(vm.rstSent, "59")
    }

    func testRadioModeUpdateAcceptsFM() {
        let vm = makeVM()
        vm.updateModeFromRadio("FM")
        XCTAssertEqual(vm.mode, "FM")
        XCTAssertEqual(vm.rstSent, "59")
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

        // Count is derived from the QSO table; enrichment is cached in history.
        let count = try await QSORepository(database: db).countForCallsign("K3ABC")
        XCTAssertEqual(count, 1)
        let history = try await CallsignHistoryRepository(database: db).fetch(callsign: "K3ABC")
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

    // MARK: - Time Editing

    func testParseEntryAppliesTimeToken() {
        let vm = makeVM()
        vm.entryText = "W1AW 1432Z"
        vm.parseEntry()
        XCTAssertEqual(vm.timeOnInput, "1432")
    }

    func testTimeTokenConsumedAfterTrailingSpace() {
        let vm = makeVM()
        vm.entryText = "W1AW 1432Z "
        vm.parseEntry()
        XCTAssertFalse(vm.entryText.contains("1432Z"), "Time token should be consumed from entry text")
        XCTAssertEqual(vm.timeOnInput, "1432")
    }

    func testTimeTokenTypingDoesNotCorruptRST() {
        // Typing "1432Z" passes through RST-shaped prefixes ("14", "143").
        // The kind flip must reset the previewed RST.
        let vm = makeVM()
        for text in ["W1AW 1", "W1AW 14", "W1AW 143", "W1AW 1432", "W1AW 1432Z"] {
            vm.entryText = text
            vm.parseEntry()
        }
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.rstReceived, "599")
        XCTAssertEqual(vm.timeOnInput, "1432")
    }

    func testFrequencyTypingDoesNotCorruptRST() {
        let vm = makeVM()
        for text in ["W1AW 1", "W1AW 14", "W1AW 14.", "W1AW 14.0", "W1AW 14.060"] {
            vm.entryText = text
            vm.parseEntry()
        }
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.frequencyText, "14.060")
    }

    func testRSTSurvivesConfirmationSpace() {
        let vm = makeVM()
        for text in ["W1AW 579", "W1AW 579 "] {
            vm.entryText = text
            vm.parseEntry()
        }
        XCTAssertEqual(vm.rstSent, "579")
    }

    func testSaveNewQSOWithTimeTokenBackTimes() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW 1432Z "
        vm.parseEntry()

        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.timeOn, "1432")
        XCTAssertEqual(vm.lastSavedQSO?.date, Date().adifDate)
        XCTAssertEqual(vm.timeOnInput, "", "Back-time must not persist to the next QSO")
    }

    func testLoadForEditingSetsTime() {
        let vm = makeVM()
        let qso = QSO(id: 42, logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        vm.loadForEditing(qso)
        XCTAssertEqual(vm.timeOnInput, "1234")
    }

    func testEditUpdatesTime() async throws {
        let vm = makeVM()
        let qsoRepo = QSORepository(database: db)
        var original = QSO(logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", frequency: 14.060, band: "20m")
        try await qsoRepo.save(&original)

        vm.loadForEditing(original)
        vm.timeOnInput = "0915"
        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.timeOn, "0915")
        XCTAssertEqual(vm.lastSavedQSO?.date, "20240101", "Date must be preserved on edit")
    }

    func testEditWithInvalidTimeKeepsOriginal() async throws {
        let vm = makeVM()
        let qsoRepo = QSORepository(database: db)
        var original = QSO(logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        try await qsoRepo.save(&original)

        vm.loadForEditing(original)
        vm.timeOnInput = "9999"
        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.timeOn, "1234")
    }

    func testTimeCommittedNormalizesAndReverts() {
        let vm = makeVM()

        // New QSO: valid 3-digit input zero-pads
        vm.timeOnInput = "932"
        vm.timeCommitted()
        XCTAssertEqual(vm.timeOnInput, "0932")

        // New QSO: invalid input reverts to empty (stamp at save)
        vm.timeOnInput = "9999"
        vm.timeCommitted()
        XCTAssertEqual(vm.timeOnInput, "")

        // Edit mode: invalid input reverts to the QSO's original time
        let qso = QSO(id: 42, logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        vm.loadForEditing(qso)
        vm.timeOnInput = ""
        vm.timeCommitted()
        XCTAssertEqual(vm.timeOnInput, "1234")
    }

    func testCancelEditingClearsTime() {
        let vm = makeVM()
        let qso = QSO(id: 42, logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        vm.loadForEditing(qso)
        vm.cancelEditing()
        XCTAssertEqual(vm.timeOnInput, "")
    }

    func testEditingDoesNotIncrementWorkedCount() async throws {
        let vm = makeVM()
        let qsoRepo = QSORepository(database: db)
        let historyRepo = CallsignHistoryRepository(database: db)

        // Log a brand-new QSO → derived worked count is 1
        vm.entryText = "K3ABC"
        vm.name = "John"
        vm.qth = "PA"
        await vm.saveQSO()
        guard let saved = vm.lastSavedQSO else { XCTFail("expected saved QSO"); return }
        var count = try await qsoRepo.countForCallsign("K3ABC")
        XCTAssertEqual(count, 1)

        // Edit that same QSO and save again — no new QSO row, so the count holds.
        vm.loadForEditing(saved)
        vm.name = "Johnny"
        await vm.saveQSO()

        count = try await qsoRepo.countForCallsign("K3ABC")
        XCTAssertEqual(count, 1, "Editing a QSO must not change the worked count")
        let history = try await historyRepo.fetch(callsign: "K3ABC")
        XCTAssertEqual(history?.name, "Johnny", "Edited details should still refresh history")
    }

    func testChangingCallsignOnEditMovesTheCount() async throws {
        let vm = makeVM()
        let qsoRepo = QSORepository(database: db)

        // Log a QSO with the wrong callsign.
        vm.entryText = "K3ABC"
        await vm.saveQSO()
        guard let saved = vm.lastSavedQSO else { XCTFail("expected saved QSO"); return }
        var oldCount = try await qsoRepo.countForCallsign("K3ABC")
        XCTAssertEqual(oldCount, 1)

        // Correct the callsign via edit.
        vm.loadForEditing(saved)
        vm.entryText = "K3XYZ"
        await vm.saveQSO()

        oldCount = try await qsoRepo.countForCallsign("K3ABC")
        let newCount = try await qsoRepo.countForCallsign("K3XYZ")
        XCTAssertEqual(oldCount, 0, "Old callsign should lose the QSO")
        XCTAssertEqual(newCount, 1, "New callsign should gain the QSO")
    }

    func testDeletingQSODecrementsDerivedCount() async throws {
        let vm = makeVM()
        let qsoRepo = QSORepository(database: db)

        vm.entryText = "K3ABC"
        await vm.saveQSO()
        guard let saved = vm.lastSavedQSO, let id = saved.id else { XCTFail("expected saved QSO"); return }
        let before = try await qsoRepo.countForCallsign("K3ABC")
        XCTAssertEqual(before, 1)

        try await qsoRepo.delete(id: id)
        let after = try await qsoRepo.countForCallsign("K3ABC")
        XCTAssertEqual(after, 0, "Deleting the QSO drops the count")
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
        // Enrichment (name/qth) is cached in history; the worked count is derived
        // from an actual prior QSO in the log.
        let historyRepo = CallsignHistoryRepository(database: db)
        try await historyRepo.recordQSO(callsign: "W1AW", name: "Hiram", qth: "CT", grid: nil)
        let qsoRepo = QSORepository(database: db)
        var prior = QSO(logId: log.id!, callsign: "W1AW", date: "20240101", timeOn: "1234", band: "20m")
        try await qsoRepo.save(&prior)

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
    }

    func testSaveEnrichesHistory() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.name = "Hiram"
        vm.qth = "CT"

        await vm.saveQSO()

        let history = try await CallsignHistoryRepository(database: db).fetch(callsign: "W1AW")
        XCTAssertEqual(history?.name, "Hiram")
        let count = try await QSORepository(database: db).countForCallsign("W1AW")
        XCTAssertEqual(count, 1)
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

    // MARK: - Mode Tests

    func testDefaultMode() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")
        XCTAssertEqual(vm.defaultRST, "599")
    }

    func testToggleModeCyclesCWSSBFM() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")

        vm.toggleMode()
        XCTAssertEqual(vm.mode, "SSB")
        XCTAssertEqual(vm.rstSent, "59")
        XCTAssertEqual(vm.rstReceived, "59")

        vm.toggleMode()
        XCTAssertEqual(vm.mode, "FM")
        XCTAssertEqual(vm.rstSent, "59")
        XCTAssertEqual(vm.rstReceived, "59")

        vm.toggleMode()
        XCTAssertEqual(vm.mode, "CW")
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.rstReceived, "599")
    }

    func testModeAutoDerivesFromFrequency() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")

        vm.frequencyText = "14.260"
        vm.frequencyChanged()
        XCTAssertEqual(vm.mode, "SSB")
        XCTAssertEqual(vm.rstSent, "59")

        vm.frequencyText = "14.060"
        vm.frequencyChanged()
        XCTAssertEqual(vm.mode, "CW")
        XCTAssertEqual(vm.rstSent, "599")
    }

    func testManualModeOverridePreventsAutoDerivation() {
        let vm = makeVM()
        vm.toggleMode()  // manual override to SSB
        XCTAssertEqual(vm.mode, "SSB")

        vm.frequencyText = "14.060"  // CW sub-band
        vm.frequencyChanged()
        XCTAssertEqual(vm.mode, "SSB", "Manual mode override should prevent auto-derivation")
    }

    func testOmnifieldModeTokenSetsMode() {
        let vm = makeVM()
        vm.entryText = "W1AW SSB "
        vm.parseEntry()
        XCTAssertEqual(vm.mode, "SSB")
        XCTAssertEqual(vm.rstSent, "59")
    }

    func testOmnifieldRSTExpandedForCW() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")
        vm.entryText = "W1AW 55"
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "559", "2-digit RST should expand to 3-digit for CW")
    }

    func testOmnifieldRSTNotExpandedForSSB() {
        let vm = makeVM()
        vm.mode = "SSB"
        vm.entryText = "W1AW 55"
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "55", "2-digit RST should stay 2-digit for SSB")
    }

    func testPrefillFromSpotSetsMode() {
        let vm = makeVM()
        let spot = makeSpot(callsign: "K3ABC", frequency: 14.260, mode: "SSB")

        vm.prefillFromSpot(spot)

        XCTAssertEqual(vm.mode, "SSB")
        XCTAssertEqual(vm.rstSent, "59")
        XCTAssertEqual(vm.rstReceived, "59")
    }

    func testLoadForEditingSetsMode() {
        let vm = makeVM()
        let qso = QSO(
            id: 42,
            logId: log.id!,
            callsign: "W1AW",
            date: "20240101",
            timeOn: "1234",
            frequency: 14.260,
            band: "20m",
            mode: "SSB",
            rstSent: "59",
            rstReceived: "59"
        )

        vm.loadForEditing(qso)

        XCTAssertEqual(vm.mode, "SSB")
        XCTAssertEqual(vm.rstSent, "59")
    }

    func testModePersistsAfterSave() async throws {
        let vm = makeVM()
        vm.mode = "SSB"
        vm.rstSent = "59"
        vm.rstReceived = "59"
        vm.entryText = "W1AW"
        vm.frequencyText = "14.260"

        await vm.saveQSO()

        XCTAssertEqual(vm.mode, "SSB", "Mode should persist after save")
        XCTAssertEqual(vm.rstSent, "59", "RST should use SSB default after save")
    }

    func testModePersistsAfterClearAllFields() {
        let vm = makeVM()
        vm.mode = "SSB"
        vm.entryText = "W1AW"

        vm.entryText = ""
        vm.callsignChanged()

        XCTAssertEqual(vm.mode, "SSB", "Mode should persist through clear")
    }

    func testRadioModeUpdateRespected() {
        let vm = makeVM()
        XCTAssertEqual(vm.mode, "CW")

        vm.updateModeFromRadio("SSB")
        XCTAssertEqual(vm.mode, "SSB")
        XCTAssertEqual(vm.rstSent, "59")
    }

    func testRadioModeUpdateAfterToggle() {
        let vm = makeVM()
        vm.toggleMode()  // toggle to SSB
        XCTAssertEqual(vm.mode, "SSB")

        // Radio sync now uses cooldown, not override blocking — after cooldown, radio wins
        vm.updateModeFromRadio("CW")
        XCTAssertEqual(vm.mode, "CW", "Radio should sync mode after cooldown expires")
    }

    func testRadioModeNilDoesNotChangeMode() {
        let vm = makeVM()
        vm.mode = "SSB"
        vm.updateModeFromRadio(nil)
        XCTAssertEqual(vm.mode, "SSB")
    }

    // MARK: - CW Template Expansion

    func testExpandTemplate_withSOTARef() {
        let vm = makeVM()
        let result = vm.expandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ SOTA DE W1AW K")
    }

    func testExpandTemplate_withPOTARef() async throws {
        let db = try AppDatabase.empty()
        let potaLog = try await makeLogWithId(in: db, potaRef: "US-4431")
        let vm = QSOEntryViewModel(database: db, log: potaLog)
        let result = vm.expandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ POTA DE W1AW K")
    }

    func testExpandTemplate_noRef() async throws {
        let db = try AppDatabase.empty()
        let noRefLog = try await makeLogWithId(in: db)
        let vm = QSOEntryViewModel(database: db, log: noRefLog)
        let result = vm.expandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ DE W1AW K")
    }

    func testExpandTemplate_exchange() {
        let vm = makeVM()
        vm.entryText = "W6SD"
        vm.rstSent = "579"
        let result = vm.expandTemplate("{call} UR {rst} BK")
        XCTAssertEqual(result, "W6SD UR 57N BK")
    }

    func testExpandTemplate_rstCutNumbers599() {
        let vm = makeVM()
        vm.entryText = "W6SD"
        vm.rstSent = "599"
        let result = vm.expandTemplate("{call} UR {rst} BK")
        XCTAssertEqual(result, "W6SD UR 5NN BK")
    }

    func testExpandTemplate_rstCutNumbers559() {
        let vm = makeVM()
        vm.entryText = "W6SD"
        vm.rstSent = "559"
        let result = vm.expandTemplate("{call} UR {rst} BK")
        XCTAssertEqual(result, "W6SD UR 55N BK")
    }

    func testPreviewTemplate_rstCutNumbers() {
        let vm = makeVM()
        vm.entryText = "W6SD"
        vm.rstSent = "599"
        let result = vm.previewExpandTemplate("{call} UR {rst} BK")
        XCTAssertEqual(result, "W6SD UR 5NN BK")
    }

    func testExpandTemplate_emptyCall() {
        let vm = makeVM()
        let result = vm.expandTemplate("{call}?")
        XCTAssertEqual(result, "?")
    }

    func testExpandTemplate_collapseSpaces() {
        let vm = makeVM()
        let result = vm.expandTemplate("{call}  DE  {myCall}")
        XCTAssertEqual(result, "DE W1AW")
    }

    // MARK: - CW Preview Template Expansion

    func testPreviewTemplate_emptyCallKeepsPlaceholder() {
        let vm = makeVM()
        let result = vm.previewExpandTemplate("{call} DE {myCall} K")
        XCTAssertEqual(result, "{call} DE W1AW K")
    }

    func testPreviewTemplate_filledCallSubstitutes() {
        let vm = makeVM()
        vm.entryText = "W6SD"
        let result = vm.previewExpandTemplate("{call} DE {myCall} K")
        XCTAssertEqual(result, "W6SD DE W1AW K")
    }

    func testPreviewTemplate_emptySOTAKeepsPlaceholder() async throws {
        let db = try AppDatabase.empty()
        let noRefLog = try await makeLogWithId(in: db)
        let vm = QSOEntryViewModel(database: db, log: noRefLog)
        let result = vm.previewExpandTemplate("{mySOTA}")
        XCTAssertEqual(result, "{mySOTA}")
    }

    func testPreviewTemplate_filledSOTASubstitutes() {
        let vm = makeVM()
        let result = vm.previewExpandTemplate("{mySOTA}")
        XCTAssertEqual(result, "W4C/CM001")
    }

    func testPreviewTemplate_mixedFilledAndEmpty() {
        let vm = makeVM()
        let result = vm.previewExpandTemplate("CQ {activity} DE {myCall} {call} K")
        XCTAssertEqual(result, "CQ SOTA DE W1AW {call} K")
    }

    func testPreviewTemplate_emptyActivityKeepsPlaceholder() async throws {
        let db = try AppDatabase.empty()
        let noRefLog = try await makeLogWithId(in: db)
        let vm = QSOEntryViewModel(database: db, log: noRefLog)
        let result = vm.previewExpandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ {activity} DE W1AW K")
    }

    func testPreviewTemplate_activityResolvesSOTA() {
        let vm = makeVM()
        let result = vm.previewExpandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ SOTA DE W1AW K")
    }

    // MARK: - Push Frequency to Radio

    func testPushFrequencyNoopWithoutService() {
        let vm = makeVM()
        vm.frequencyText = "7.030"
        vm.pushFrequencyToRadio()  // no crash, no-op
    }

    func testPushFrequencyNoopWithInvalidFrequency() {
        let vm = makeVM()
        vm.sotaCatService = SOTACatService()
        vm.frequencyText = "abc"
        vm.pushFrequencyToRadio()  // no crash, no-op
    }

    func testPushModeNoopWithoutService() {
        let vm = makeVM()
        vm.pushModeToRadio()  // no crash, no-op
    }

    // MARK: - CW Template Dash Stripping

    func testExpandTemplate_stripsSOTADash() {
        let vm = makeVM()
        let result = vm.expandTemplate("{mySOTA}")
        XCTAssertEqual(result, "W4C/CM001", "Dashes should be stripped from SOTA ref for CW")
    }

    func testExpandTemplate_stripsPOTADash() async throws {
        let db = try AppDatabase.empty()
        let potaLog = try await makeLogWithId(in: db, potaRef: "US-4431")
        let vm = QSOEntryViewModel(database: db, log: potaLog)
        let result = vm.expandTemplate("{myPOTA}")
        XCTAssertEqual(result, "US4431", "Dashes should be stripped from POTA ref for CW")
    }

    func testExpandTemplate_preservesSlash() {
        let vm = makeVM()
        let result = vm.expandTemplate("{mySOTA}")
        XCTAssertTrue(result.contains("/"), "Slashes should be preserved (valid Morse prosign)")
    }

    func testPreviewTemplate_activityResolvesPOTA() async throws {
        let db = try AppDatabase.empty()
        let potaLog = try await makeLogWithId(in: db, potaRef: "US-4431")
        let vm = QSOEntryViewModel(database: db, log: potaLog)
        let result = vm.previewExpandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ POTA DE W1AW K")
    }

    // MARK: - Maidenhead Grid (omnifield + preview-clear leak)

    func testParseEntryAppliesGrid() {
        let vm = makeVM()
        vm.entryText = "W1AW CM87"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "CM87")
        XCTAssertEqual(vm.potaRefInput, "", "CM87 must not also populate POTA")
    }

    func testParseEntryCanonicalizesGrid() {
        let vm = makeVM()
        vm.entryText = "W1AW fn31PR"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "FN31pr")
    }

    func testGridPreviewClearsWhenTypingBeyondValidLength() {
        let vm = makeVM()
        // Type "FN31" → grid set
        vm.entryText = "W1AW FN31"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "FN31")
        // Keep typing "FN31m" → 5 chars, not a valid grid, not POTA either
        vm.entryText = "W1AW FN31m"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "", "5-char intermediate should clear stale grid preview")
        // Keep typing "FN31ma" → 6-char grid, set again
        vm.entryText = "W1AW FN31ma"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "FN31ma")
    }

    func testGridPreviewClearsWhenTransitioningFromPOTAToGrid() {
        // Pre-existing bug: type "FN31" once → potaRefInput got "FN31" stale.
        // After fix: "FN31" now classifies as grid (precedence). But what if user types something
        // that's POTA then transitions to grid? e.g. "K1234" (POTA) then deletes/retypes.
        // More direct: type a POTA candidate that's also not a grid, then transition to grid.
        let vm = makeVM()
        vm.entryText = "W1AW K1234"
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "K1234")
        // Now blow it away and type a grid
        vm.entryText = "W1AW CM87"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "CM87")
        XCTAssertEqual(vm.potaRefInput, "", "Stale POTA preview should clear when last token becomes grid")
    }

    func testConfirmedPOTAStaysStickyWhenGridPreviewAppears() {
        // Confirmed (consumed) tokens must NOT be cleared by preview-flip.
        let vm = makeVM()
        // Confirm POTA by adding trailing space — token is consumed (stripped from entryText)
        vm.entryText = "W1AW US4431 "
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "US4431")
        XCTAssertFalse(vm.entryText.contains("US4431"), "POTA token should be consumed")

        // Operator types a grid onto the already-consumed state
        vm.entryText += "CM87"
        vm.parseEntry()

        XCTAssertEqual(vm.potaRefInput, "US4431", "Confirmed POTA must remain")
        XCTAssertEqual(vm.gridInput, "CM87")
    }

    func testGridPreviewClearsWhenLastTokenBecomesUnrecognized() {
        let vm = makeVM()
        vm.entryText = "W1AW CM87"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "CM87")
        // Keep typing into something unrecognized — y/z are outside the a-x sub-square range
        vm.entryText = "W1AW CM87yz"
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "", "Invalid 6-char grid should clear stale preview")
    }

    func testGridConsumedAfterTrailingSpace() {
        let vm = makeVM()
        vm.entryText = "W1AW CM87 "
        vm.parseEntry()
        // Token should be consumed (stripped from entryText), grid value retained
        XCTAssertEqual(vm.gridInput, "CM87")
        XCTAssertFalse(vm.entryText.contains("CM87"), "Grid token should be consumed from entry text")
    }

    func testSavePersistsCanonicalizedGrid() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "14.060"
        vm.gridInput = "fn31PR"

        await vm.saveQSO()

        XCTAssertEqual(vm.lastSavedQSO?.grid, "FN31pr", "Typed grid should be canonicalized before persisting")
    }

    func testSaveDropsInvalidTypedGrid() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "14.060"
        vm.gridInput = "FOO123"

        await vm.saveQSO()

        XCTAssertNotNil(vm.lastSavedQSO)
        XCTAssertNil(vm.lastSavedQSO?.grid, "Invalid typed grid must not leak into the saved QSO / ADIF")
    }

    func testConfirmedGridStaysStickyWhenTypingMore() {
        let vm = makeVM()
        vm.entryText = "W1AW CM87 "
        vm.parseEntry()  // consumes CM87
        XCTAssertEqual(vm.gridInput, "CM87")
        XCTAssertFalse(vm.entryText.contains("CM87"), "Grid token should be consumed")

        // Operator types more onto the consumed state (e.g., adds an RST)
        vm.entryText += "59"
        vm.parseEntry()

        XCTAssertEqual(vm.gridInput, "CM87", "Confirmed grid must remain")
        XCTAssertEqual(vm.rstSent, "599", "RST 59 expands to 599 for CW")
    }

    func testEditingClearedGridSavesNil() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.frequencyText = "14.060"
        vm.gridInput = "CM87"
        await vm.saveQSO()
        guard let saved = vm.lastSavedQSO else { XCTFail("expected saved QSO"); return }
        XCTAssertEqual(saved.grid, "CM87")

        vm.loadForEditing(saved)
        XCTAssertEqual(vm.gridInput, "CM87")
        vm.gridInput = ""
        await vm.saveQSO()

        XCTAssertNil(vm.lastSavedQSO?.grid, "Clearing pill during edit must drop the saved grid")
    }

    func testQTHPreviewClearAlsoDropsManualOverride() {
        let vm = makeVM()
        vm.entryText = "W1AW CA"
        vm.parseEntry()
        XCTAssertEqual(vm.qth, "CA")
        XCTAssertTrue(vm.hasManualOverride("qth"))

        // Type past it — "CAR" is unrecognized (not a QTH, not POTA, not grid)
        vm.entryText = "W1AW CAR"
        vm.parseEntry()
        XCTAssertEqual(vm.qth, "")
        XCTAssertFalse(vm.hasManualOverride("qth"),
                       "Preview-clear must drop the override so QRZ/history can fill the empty field")
    }

    func testPOTAPreviewClearAlsoDropsManualOverride() {
        let vm = makeVM()
        vm.entryText = "W1AW K1234"
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "K1234")
        XCTAssertTrue(vm.hasManualOverride("potaRef"))

        // Transition to a grid — preview-clear should empty POTA and drop its override
        vm.entryText = "W1AW CM87"
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "")
        XCTAssertFalse(vm.hasManualOverride("potaRef"))
    }
}
