import XCTest
@testable import SOTALog
import HamCore

final class QSOEntryViewModelTests: XCTestCase {

    private var db: LogbookDatabase!
    private var log: Log!

    override func setUp() async throws {
        db = try LogbookDatabase.empty()
        log = try await makeLogWithId(in: db, potaRef: "US-4431", sotaRef: "W4C/CM-001")
    }

    private func makeVM() -> QSOEntryViewModel {
        QSOEntryViewModel(database: db, log: log)
    }

    /// Types `text` one character at a time, parsing after each, as the field does.
    private func type(_ text: String, into vm: QSOEntryViewModel) {
        for character in text {
            vm.entryText.append(character)
            vm.parseEntry()
        }
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
        vm.entryText = "W1AW 579 "
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "579")
    }

    func testParseEntryAppliesFrequency() {
        let vm = makeVM()
        vm.entryText = "W1AW 7.030 "
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "7.030")
    }

    func testParseEntryAppliesQTH() {
        let vm = makeVM()
        vm.entryText = "W1AW NC "
        vm.parseEntry()
        XCTAssertEqual(vm.qth, "NC")
    }

    func testParseEntryAppliesPOTARef() {
        let vm = makeVM()
        vm.entryText = "W1AW US0001 "
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "US0001")
    }

    func testParseEntryAppliesSOTARef() {
        let vm = makeVM()
        vm.entryText = "W1AW W4CCM001 "
        vm.parseEntry()
        XCTAssertEqual(vm.sotaRefInput, "W4CCM001")
    }

    func testWordBeingTypedIsNotAppliedUntilSpace() {
        let vm = makeVM()
        vm.entryText = "W1AW 579 NC"
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "579")
        XCTAssertEqual(vm.qth, "")

        vm.entryText = "W1AW 579 NC "
        vm.parseEntry()
        XCTAssertEqual(vm.qth, "NC")
    }

    func testConfirmEntryAppliesTheLastWord() {
        let vm = makeVM()
        vm.entryText = "W1AW 579"
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "599")
        vm.confirmEntry()
        XCTAssertEqual(vm.rstSent, "579")
    }

    func testDeletingAnRSTWordRestoresTheDefault() {
        let vm = makeVM()
        type("W1AW 44 ", into: vm)
        XCTAssertEqual(vm.rstSent, "449")
        vm.entryText = "W1AW "
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "599")
    }

    func testRSTSetOnTheChipSurvivesTyping() {
        let vm = makeVM()
        vm.rstSent = "339"
        vm.markManualOverride("rstSent")
        type("W1AW CA ", into: vm)
        XCTAssertEqual(vm.rstSent, "339")
    }

    func testSaveAppliesTheLastWord() async throws {
        let vm = makeVM()
        vm.entryText = "W1AW 44"
        await vm.saveQSO()
        XCTAssertEqual(vm.lastSavedQSO?.rstSent, "449")
    }

    // MARK: - Omnifield Overrides Manual Fields

    func testOmnifieldOverridesManualFrequency() {
        let vm = makeVM()
        vm.frequencyText = "7.030"
        vm.markManualOverride("frequency")
        vm.entryText = "W1AW 14.060 "
        vm.parseEntry()
        XCTAssertEqual(vm.frequencyText, "14.060")
    }

    func testOmnifieldOverridesManualRST() {
        let vm = makeVM()
        vm.rstSent = "559"
        vm.markManualOverride("rstSent")
        vm.entryText = "W1AW 579 "
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "579")
    }

    func testOmnifieldOverridesMultipleManualFields() {
        let vm = makeVM()
        vm.frequencyText = "7.030"
        vm.rstSent = "559"
        vm.markManualOverride("frequency")
        vm.markManualOverride("rstSent")
        vm.entryText = "W1AW 579 14.060 "
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

    func testSavedDetailsAreLookedUpNextTime() async throws {
        let vm = makeVM()
        vm.entryText = "K3ABC"
        vm.name = "John"
        vm.qth = "PA"

        await vm.saveQSO()

        // Both the count and the details are read back from the log.
        let count = try await QSORepository(database: db).countForCallsign("K3ABC")
        XCTAssertEqual(count, 1)
        vm.entryText = "K3ABC"
        vm.callsignChanged()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(vm.name, "John")
        XCTAssertEqual(vm.qth, "PA")
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
        vm.entryText = "K3ABC 7.030 "
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
        vm.entryText = "W1AW 1432Z "
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
        // Typing "1432Z" passes through RST-shaped prefixes ("14", "143"), which are never applied.
        let vm = makeVM()
        type("W1AW 1432Z ", into: vm)
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.rstReceived, "599")
        XCTAssertEqual(vm.timeOnInput, "1432")
    }

    func testFrequencyTypingDoesNotCorruptRST() {
        let vm = makeVM()
        type("W1AW 7.030 ", into: vm)
        XCTAssertEqual(vm.rstSent, "599")
        XCTAssertEqual(vm.frequencyText, "7.030")
    }

    func testRSTSurvivesConfirmationSpace() {
        let vm = makeVM()
        for text in ["W1AW 579", "W1AW 579 "] {
            vm.entryText = text
            vm.parseEntry()
        }
        XCTAssertEqual(vm.rstSent, "579")
    }

    // MARK: - Correcting the callsign by retyping it

    func testRetypedCallsignReplacesFirstAndKeepsRST() {
        let vm = makeVM()
        type("K6ABC 55 57 K6ABD ", into: vm)
        XCTAssertEqual(vm.entryText, "K6ABD 55 57 ")
        XCTAssertEqual(vm.parsedCallsign, "K6ABD")
        XCTAssertEqual(vm.rstSent, "559")
        XCTAssertEqual(vm.rstReceived, "579")
    }

    func testFullCallsignReplacesTailEndPartial() {
        let vm = makeVM()
        type("ABC 55 K6ABC ", into: vm)
        XCTAssertEqual(vm.entryText, "K6ABC 55 ")
    }

    func testCallsignBeingTypedStaysUntilSpace() {
        let vm = makeVM()
        type("K6ABC 55 K6AB", into: vm)
        XCTAssertEqual(vm.entryText, "K6ABC 55 K6AB")
        XCTAssertEqual(vm.parsedCallsign, "K6ABC")
    }

    func testPartialCallsignAfterRSTDoesNotReplace() {
        let vm = makeVM()
        type("K6ABC 55 K6 ", into: vm)
        XCTAssertEqual(vm.parsedCallsign, "K6ABC")
        XCTAssertEqual(vm.entryText, "K6ABC 55 K6 ")
    }

    func testShorthandAfterRSTDoesNotReplace() {
        let vm = makeVM()
        type("K6ABC 55 P2P ", into: vm)
        XCTAssertEqual(vm.parsedCallsign, "K6ABC")
    }

    func testRetypingTheSameCallsignKeepsDetails() {
        let vm = makeVM()
        type("K6ABC 55 ", into: vm)
        vm.name = "Jane"
        vm.timesWorked = 3
        type("K6ABC ", into: vm)
        XCTAssertEqual(vm.entryText, "K6ABC 55 ")
        XCTAssertEqual(vm.name, "Jane")
        XCTAssertEqual(vm.timesWorked, 3)
    }

    func testPortableRegionSuffixReplacesNotSummit() {
        let vm = makeVM()
        type("K6ABC 55 K6ABC/7 ", into: vm)
        XCTAssertEqual(vm.entryText, "K6ABC/7 55 ")
        XCTAssertEqual(vm.sotaRefInput, "")
    }

    func testCorrectionClearsLookedUpNameButKeepsTypedQTH() {
        let vm = makeVM()
        type("K6ABC 55 CA ", into: vm)
        vm.name = "Jane"
        vm.timesWorked = 3
        vm.workedToday = 1
        vm.isDupe = true
        type("W7XYZ ", into: vm)
        XCTAssertEqual(vm.name, "")
        XCTAssertEqual(vm.qth, "CA")
        XCTAssertEqual(vm.timesWorked, 0)
        XCTAssertEqual(vm.workedToday, 0)
        XCTAssertFalse(vm.isDupe)
    }

    func testCorrectionDropsReferenceFromOldCallsignsSpot() async throws {
        let vm = makeVM()
        vm.spotLookup = { call in
            guard call == "K6ABC" else { return nil }
            return makeSpot(callsign: "K6ABC", frequency: 14.062, sotaReference: "W6/CT-002")
        }
        type("K6ABC 55", into: vm)
        vm.callsignChanged()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(vm.sotaRefInput, "W6CT002")

        type(" K6ABD ", into: vm)
        XCTAssertEqual(vm.sotaRefInput, "")
    }

    func testCorrectionKeepsReferenceFromTappedSpot() {
        let vm = makeVM()
        vm.prefillFromSpot(makeSpot(callsign: "K3ABC", frequency: 14.062, sotaReference: "W4C/CM-001"))
        type(" 55 K3ABD ", into: vm)
        XCTAssertEqual(vm.entryText, "K3ABD 55 ")
        XCTAssertEqual(vm.sotaRefInput, "W4CCM001")
    }

    func testCorrectionWhileEditingDropsSavedGridButKeepsReferences() async throws {
        let vm = makeVM()
        vm.loadForEditing(QSO(
            id: 42, logId: log.id!, callsign: "K6ABC", date: "20240101", timeOn: "1234",
            frequency: 14.062, band: "20m", mode: "CW", rstSent: "599", rstReceived: "599",
            name: "Jane", qth: "CA", grid: "CM87", sotaRef: "W6/CT-002"
        ))
        type(" K6ABD ", into: vm)
        XCTAssertEqual(vm.sotaRefInput, "W6CT002")
        await vm.saveQSO()
        XCTAssertEqual(vm.lastSavedQSO?.callsign, "K6ABD")
        XCTAssertNil(vm.lastSavedQSO?.name)
        XCTAssertNil(vm.lastSavedQSO?.grid)
    }

    func testCorrectionThroughAStatePrefixKeepsTypedQTH() {
        let vm = makeVM()
        type("K6ABC 55 CA ", into: vm)
        type("VA3XYZ ", into: vm)
        XCTAssertEqual(vm.entryText, "VA3XYZ 55 ")
        XCTAssertEqual(vm.qth, "CA")
        XCTAssertTrue(vm.hasManualOverride("qth"))
    }

    func testCorrectionThroughAParkShapeKeepsTypedPark() {
        let vm = makeVM()
        type("K6ABC 55 US-0041 ", into: vm)
        type("KD9XYZ ", into: vm)
        XCTAssertEqual(vm.entryText, "KD9XYZ 55 ")
        XCTAssertEqual(vm.potaRefInput, "US-0041")
    }

    func testTokenPreviewingAnotherKindKeepsTypedFields() {
        let vm = makeVM()
        type("K6ABC NC ", into: vm)
        type("CA-1234 ", into: vm)
        XCTAssertEqual(vm.qth, "NC")

        let other = makeVM()
        type("K6ABC US-0041 ", into: other)
        type("FN31 ", into: other)
        XCTAssertEqual(other.potaRefInput, "US-0041")
        XCTAssertEqual(other.gridInput, "FN31")
    }

    func testCorrectionWhileEditingSavesTheNewStationsGridFromTheLog() async throws {
        let vm = makeVM()
        vm.entryText = "K6ABD"
        vm.gridInput = "FN31"
        await vm.saveQSO()

        vm.loadForEditing(QSO(
            id: 42, logId: log.id!, callsign: "K6ABC", date: "20240101", timeOn: "1234",
            frequency: 14.062, band: "20m", mode: "CW", rstSent: "599", rstReceived: "599",
            grid: "CM87"
        ))
        type(" K6ABD", into: vm)
        await vm.saveQSO()
        XCTAssertEqual(vm.lastSavedQSO?.callsign, "K6ABD")
        XCTAssertEqual(vm.lastSavedQSO?.grid, "FN31")
    }

    func testDeletingATypedRSTWhileEditingRestoresTheSavedRST() {
        let vm = makeVM()
        vm.loadForEditing(QSO(
            id: 42, logId: log.id!, callsign: "K6ABC", date: "20240101", timeOn: "1234",
            frequency: 14.062, band: "20m", mode: "CW", rstSent: "449", rstReceived: "339"
        ))
        type(" 57 ", into: vm)
        XCTAssertEqual(vm.rstSent, "579")
        vm.entryText = "K6ABC "
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "449")
        XCTAssertEqual(vm.rstReceived, "339")
    }

    func testCallsignShapedPartialReplacesOnSpace() {
        let vm = makeVM()
        type("K6ABC 55 K6A ", into: vm)
        XCTAssertEqual(vm.entryText, "K6A 55 ")
    }

    func testCWKeyMidCallLeavesTheCallToFinish() {
        let vm = makeVM()
        type("W7X", into: vm)
        XCTAssertEqual(vm.expandTemplate("{call}?"), "W7X?")
        vm.sendCWMacro("{call}?")
        type("YZ", into: vm)
        XCTAssertEqual(vm.entryText, "W7XYZ")
        XCTAssertEqual(vm.parsedCallsign, "W7XYZ")
    }

    func testCWKeySendsTypedWordsWithoutApplyingThem() {
        let vm = makeVM()
        type("K6ABC 55 VA", into: vm)
        vm.sendCWMacro("{call}?")
        XCTAssertEqual(vm.entryText, "K6ABC 55 VA")
        XCTAssertEqual(vm.qth, "")

        let unfinishedRST = makeVM()
        type("K6ABC 55", into: unfinishedRST)
        XCTAssertEqual(unfinishedRST.expandTemplate("{call} UR {rst}"), "K6ABC UR 55N")
        XCTAssertEqual(unfinishedRST.rstSent, "599")

        let unfinishedCorrection = makeVM()
        type("K6ABC 55 W7X", into: unfinishedCorrection)
        XCTAssertEqual(unfinishedCorrection.expandTemplate("{call} UR {rst}"), "W7X UR 55N")
        XCTAssertEqual(unfinishedCorrection.parsedCallsign, "K6ABC")
    }

    func testChipEditAfterAnUnfinishedWordWins() async throws {
        let vm = makeVM()
        type("W1AW 55 CA", into: vm)
        vm.confirmEntry() // opening a chip finishes the word first
        vm.qth = "OR"
        vm.markManualOverride("qth")
        vm.rstSent = "449"
        vm.markManualOverride("rstSent")
        await vm.saveQSO()
        XCTAssertEqual(vm.lastSavedQSO?.qth, "OR")
        XCTAssertEqual(vm.lastSavedQSO?.rstSent, "449")
    }

    func testConfirmLeavesALoneCallsignToFinish() {
        let vm = makeVM()
        type("W7X", into: vm)
        vm.confirmEntry()
        XCTAssertEqual(vm.entryText, "W7X")
    }

    func testCorrectionCancelsTheOldCallsignsPendingLookup() async throws {
        let vm = makeVM()
        vm.spotLookup = { call in
            call == "K6ABC" ? makeSpot(callsign: "K6ABC", frequency: 14.062, potaReference: "US-0041") : nil
        }
        type("K6ABC 55 K6ABD", into: vm)
        vm.callsignChanged()
        vm.confirmEntry()
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(vm.parsedCallsign, "K6ABD")
        XCTAssertEqual(vm.potaRefInput, "")
    }

    func testShorteningTheCallsignKeepsTypedQTH() {
        let vm = makeVM()
        type("K6ABC 55 CA ", into: vm)
        vm.entryText = "K6 55 "
        vm.parseEntry()
        vm.callsignChanged()
        XCTAssertEqual(vm.qth, "CA")
    }

    func testSendSavesCorrectionStillBeingTyped() async throws {
        let vm = makeVM()
        type("K6ABC 55 K6ABD", into: vm)
        await vm.saveQSO()
        XCTAssertEqual(vm.lastSavedQSO?.callsign, "K6ABD")
        XCTAssertEqual(vm.lastSavedQSO?.rstSent, "559")
    }

    func testSendCorrectionFillsDetailsFromTheLog() async throws {
        let vm = makeVM()
        vm.entryText = "K6ABD"
        vm.name = "Bob"
        await vm.saveQSO()

        type("K6ABC 55 K6ABD", into: vm)
        await vm.saveQSO()
        XCTAssertEqual(vm.lastSavedQSO?.callsign, "K6ABD")
        XCTAssertEqual(vm.lastSavedQSO?.name, "Bob")
        XCTAssertEqual(vm.lastSavedQSO?.qth, "CA")
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
        let details = try await qsoRepo.details(forCallsign: "K3ABC")
        XCTAssertEqual(details?.name, "Johnny", "The next lookup should see the edited details")
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

    // MARK: - Dupe Detection

    /// Seeds two summits so typed references validate, and logs a prior 20m CW contact with
    /// K3ABC, optionally from a summit.
    private func seedDupeFixtures(priorSummit: String?) async throws {
        try await ReferenceRepository(database: db).importSummits([
            SOTASummit(code: "W6/NC-001", codeNormalized: "W6NC001", name: "Mount Tamalpais"),
            SOTASummit(code: "W6/NC-002", codeNormalized: "W6NC002", name: "Mount Diablo"),
        ])
        var prior = QSO(logId: log.id!, callsign: "K3ABC", date: "20240101", timeOn: "1200", band: "20m", mode: "CW", sotaRef: priorSummit)
        try await QSORepository(database: db).save(&prior)
    }

    func testSameStationFromSameSummitIsDupe() async throws {
        try await seedDupeFixtures(priorSummit: "W6/NC-001")
        let vm = makeVM()

        vm.entryText = "K3ABC W6NC001 "
        vm.parseEntry()
        vm.callsignChanged()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(vm.isDupe)
    }

    func testSameStationFromDifferentSummitIsNotDupe() async throws {
        try await seedDupeFixtures(priorSummit: "W6/NC-001")
        let vm = makeVM()

        vm.entryText = "K3ABC W6NC002 "
        vm.parseEntry()
        vm.callsignChanged()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertFalse(vm.isDupe, "A different summit is a new S2S contact")
    }

    func testDupeClearsWhenSummitReferenceIsAdded() async throws {
        try await seedDupeFixtures(priorSummit: nil)
        let vm = makeVM()

        vm.entryText = "K3ABC"
        vm.callsignChanged()
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(vm.isDupe, "Same station, band, and mode with no references is a dupe")

        // The operator adds the other station's summit via the chip editor: now it's S2S.
        vm.sotaRefInput = "W6NC001"
        vm.validateSOTARef()
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(vm.isDupe, "Validating a reference re-runs the dupe check")
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

    /// Saves a prior contact with W1AW, as a QRZ download would leave it: no log.
    private func logPriorContact(date: String = "20240101", name: String?, qth: String?) async throws {
        var prior = QSO(callsign: "W1AW", date: date, timeOn: "1234", band: "20m",
                        name: name, qth: qth, syncedToQRZ: true)
        try await QSORepository(database: db).save(&prior)
    }

    func testCallsignChangedPopulatesFromTheLog() async throws {
        // Name, QTH and the worked count all come from prior contacts in the log.
        try await logPriorContact(name: "Hiram", qth: "CT")

        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.name, "Hiram")
        XCTAssertEqual(vm.qth, "CT")
        XCTAssertEqual(vm.timesWorked, 1)
    }

    func testCallsignChangedTakesEachFieldFromTheNewestContactThatHasIt() async throws {
        try await logPriorContact(date: "20240101", name: "Hiram Percy Maxim", qth: "CT")
        try await logPriorContact(date: "20240301", name: "Hiram", qth: nil)

        let vm = makeVM()
        vm.entryText = "W1AW"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.name, "Hiram")
        XCTAssertEqual(vm.qth, "CT")
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

    func testTheLogDoesNotOverwriteExistingFields() async throws {
        try await logPriorContact(name: "Hiram", qth: "CT")

        let vm = makeVM()
        vm.name = "Manual Name"
        vm.entryText = "W1AW"
        vm.callsignChanged()

        try await Task.sleep(for: .milliseconds(500))

        // The log is LOW authority — should not overwrite non-empty name
        XCTAssertEqual(vm.name, "Manual Name")
    }

    func testShortCallsignClearsLookup() async throws {
        try await logPriorContact(name: "Hiram", qth: "CT")

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
        vm.entryText = "K3ABC 7.030 "
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
        vm.entryText = "W1AW 55 "
        vm.parseEntry()
        XCTAssertEqual(vm.rstSent, "559", "2-digit RST should expand to 3-digit for CW")
    }

    func testOmnifieldRSTNotExpandedForSSB() {
        let vm = makeVM()
        vm.mode = "SSB"
        vm.entryText = "W1AW 55 "
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
        let db = try LogbookDatabase.empty()
        let potaLog = try await makeLogWithId(in: db, potaRef: "US-4431")
        let vm = QSOEntryViewModel(database: db, log: potaLog)
        let result = vm.expandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ POTA DE W1AW K")
    }

    func testExpandTemplate_noRef() async throws {
        let db = try LogbookDatabase.empty()
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
        let db = try LogbookDatabase.empty()
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
        let db = try LogbookDatabase.empty()
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
        let db = try LogbookDatabase.empty()
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
        let db = try LogbookDatabase.empty()
        let potaLog = try await makeLogWithId(in: db, potaRef: "US-4431")
        let vm = QSOEntryViewModel(database: db, log: potaLog)
        let result = vm.previewExpandTemplate("CQ {activity} DE {myCall} K")
        XCTAssertEqual(result, "CQ POTA DE W1AW K")
    }

    // MARK: - Maidenhead Grid

    func testParseEntryAppliesGrid() {
        let vm = makeVM()
        vm.entryText = "W1AW CM87 "
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "CM87")
        XCTAssertEqual(vm.potaRefInput, "", "CM87 must not also populate POTA")
    }

    func testParseEntryCanonicalizesGrid() {
        let vm = makeVM()
        vm.entryText = "W1AW fn31PR "
        vm.parseEntry()
        XCTAssertEqual(vm.gridInput, "FN31pr")
    }

    func testGridTypedThroughShorterShapesSetsOnlyTheFinishedGrid() {
        // "FN31ma" passes through a 4-char grid and a 5-char non-grid; neither is applied.
        let vm = makeVM()
        type("W1AW FN31ma", into: vm)
        XCTAssertEqual(vm.gridInput, "")
        type(" ", into: vm)
        XCTAssertEqual(vm.gridInput, "FN31ma")
    }

    func testConfirmedPOTAStaysStickyWhenTypingAGrid() {
        let vm = makeVM()
        vm.entryText = "W1AW US4431 "
        vm.parseEntry()
        XCTAssertEqual(vm.potaRefInput, "US4431")
        XCTAssertFalse(vm.entryText.contains("US4431"), "POTA token should be consumed")

        type("CM87 ", into: vm)
        XCTAssertEqual(vm.potaRefInput, "US4431", "Confirmed POTA must remain")
        XCTAssertEqual(vm.gridInput, "CM87")
    }

    func testHalfTypedWordsChangeNoField() {
        let vm = makeVM()
        type("W1AW CAR K1234X CM87yz", into: vm)
        XCTAssertEqual(vm.qth, "")
        XCTAssertEqual(vm.potaRefInput, "")
        XCTAssertEqual(vm.gridInput, "")
        XCTAssertFalse(vm.hasManualOverride("qth"))
        XCTAssertFalse(vm.hasManualOverride("potaRef"))
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
}
