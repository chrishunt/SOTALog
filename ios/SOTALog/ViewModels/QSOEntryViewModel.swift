import Foundation
import HamCore
import Observation

@Observable
final class QSOEntryViewModel {
    private let database: LogbookDatabase
    private let log: Log
    private let qsoRepo: QSORepository
    private let refRepo: ReferenceRepository

    // Omnifield input (space-separated tokens: callsign + optional overrides)
    var entryText: String = ""

    // Field state
    var rstSent: String = "599"
    var rstReceived: String = "599"
    var frequencyText: String = "14.060"
    var mode: String = "CW"
    var name: String = ""
    var qth: String = ""
    var potaRefInput: String = ""
    var potaRefFormatted: String?
    var potaRefName: String?
    var potaRefValid: Bool = false
    var sotaRefInput: String = ""
    var sotaRefFormatted: String?
    var sotaRefValid: Bool = false
    var gridInput: String = ""
    // Time pill value ("HHMM" UTC digits). Empty means "stamp at save" for new QSOs;
    // during edit it holds the QSO's time and an invalid value falls back to the original.
    var timeOnInput: String = ""

    // Tracks which fields were manually edited (not set by omnifield)
    private var manualOverrides: Set<String> = []

    // Whether each RST came from a word in the entry field. RST words stay in the field, so
    // deleting or retyping one puts its chip back to the default.
    private var rstSentFromEntry = false
    private var rstReceivedFromEntry = false

    // Editing state
    var editingQSO: QSO?
    var isEditing: Bool { editingQSO != nil }

    // Lookup state
    var timesWorked: Int = 0
    var workedToday: Int = 0
    var isDupe: Bool = false
    var lastSavedQSO: QSO?
    var saveCount: Int = 0

    /// The callsign extracted from the first token of entryText
    var parsedCallsign: String {
        let first = entryText.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return first.sanitizedCallsign
    }

    /// Default RST based on current mode (CW = 599, voice modes = 59)
    var defaultRST: String {
        mode == "CW" ? "599" : "59"
    }

    /// The other station's summit/park as they would be saved: the validated, formatted code, or nil.
    private var resolvedSotaRef: String? { sotaRefValid ? sotaRefFormatted : nil }
    private var resolvedPotaRef: String? { potaRefValid ? potaRefFormatted : nil }

    // CW Keyer
    var keyerSendCount: Int = 0

    var spotLookup: ((String) -> Spot?)?
    var qrzLookup: QRZLookupService?
    var sotaCatService: SOTACatService?

    private var lookupTask: Task<Void, Never>?
    // Hidden auto-populated grid from QRZ or the log. Saved on the QSO and exported to ADIF,
    // but never shown as a pill — the pill only appears when the operator types a grid.
    private var grid: String?
    private var frequencyPushTime: Date?
    private var modePushTime: Date?
    private let pushCooldown: TimeInterval = 2

    init(database: LogbookDatabase, log: Log) {
        self.database = database
        self.log = log
        self.qsoRepo = QSORepository(database: database)
        self.refRepo = ReferenceRepository(database: database)
    }

    // MARK: - Mode

    /// Cycles CW → SSB → FM → CW, marks as manual override, updates RST defaults
    func toggleMode() {
        switch mode {
        case "CW":  mode = "SSB"
        case "SSB": mode = "FM"
        default:    mode = "CW"
        }
        markManualOverride("mode")
        updateRSTForMode()
        recheckDupe()
        pushModeToRadio()
    }

    /// Auto-derives mode from frequency when mode is not manually overridden.
    /// Skipped when radio is connected — mode comes from the radio, not band-plan derivation.
    func updateModeFromFrequency() {
        guard !manualOverrides.contains("mode") else { return }
        if let service = sotaCatService, service.isConnected { return }
        guard let freq = Double(frequencyText),
              let derived = BandPlan.mode(for: freq) else { return }
        if mode != derived {
            mode = derived
            updateRSTForMode()
        }
    }

    /// Updates mode from SOTACat radio poll, with cooldown after app→radio push
    func updateModeFromRadio(_ radioMode: String?) {
        guard let radioMode, !radioMode.isEmpty else { return }
        if let pushTime = modePushTime, Date().timeIntervalSince(pushTime) < pushCooldown { return }
        let upper = radioMode.uppercased()
        guard upper == "CW" || upper == "SSB" || upper == "FM" else { return }
        if mode != upper {
            mode = upper
            updateRSTForMode()
        }
    }

    /// Updates RST defaults when mode changes (only if not manually overridden)
    private func updateRSTForMode() {
        if !manualOverrides.contains("rstSent") {
            rstSent = defaultRST
        }
        if !manualOverrides.contains("rstReceived") {
            rstReceived = defaultRST
        }
    }

    /// Expands a parsed RST value based on current mode: for CW, 2-digit → append "9"
    private func expandRST(_ raw: String) -> String {
        if raw.count == 2 && mode == "CW" {
            return raw + "9"
        }
        return raw
    }

    // MARK: - Omnifield Parsing

    /// Applies the words the operator has finished: the ones followed by a space. The word
    /// still being typed waits for a space or Send (`confirmEntry()`), so a half-typed word
    /// never changes a field, as `VA3XYZ` would otherwise be read as a state at `VA`.
    func parseEntry() {
        let parsed = OmniFieldParser.parse(entryText)
        let finishedText = entryText.hasSuffix(" ")
            ? entryText
            : entryText.split(separator: " ").dropLast().joined(separator: " ")
        let finished = finishedText == entryText ? parsed : OmniFieldParser.parse(finishedText)

        if let parsedMode = finished.mode {
            mode = parsedMode
            markManualOverride("mode")
            updateRSTForMode()
        }

        if let rst = finished.rstSent {
            rstSent = expandRST(rst)
            markManualOverride("rstSent")
            rstSentFromEntry = true
        } else if rstSentFromEntry {
            rstSent = editingQSO?.rstSent ?? defaultRST
            manualOverrides.remove("rstSent")
            rstSentFromEntry = false
        }
        if let rst = finished.rstReceived {
            rstReceived = expandRST(rst)
            markManualOverride("rstReceived")
            rstReceivedFromEntry = true
        } else if rstReceivedFromEntry {
            rstReceived = editingQSO?.rstReceived ?? defaultRST
            manualOverrides.remove("rstReceived")
            rstReceivedFromEntry = false
        }

        if let freq = finished.frequency {
            frequencyText = freq
            markManualOverride("frequency")
            updateModeFromFrequency()
        }
        if let q = finished.qth {
            qth = q
            markManualOverride("qth")
        }
        if let g = finished.gridSquare {
            gridInput = g
        }
        if let ref = finished.potaRef {
            potaRefInput = ref
            markManualOverride("potaRef")
            validatePOTARef()
        }
        if let ref = finished.sotaRef {
            sotaRefInput = ref
            markManualOverride("sotaRef")
            validateSOTARef()
        }
        if let time = finished.timeOn {
            timeOnInput = time
        }

        consumeTokens(parsed)
    }

    /// Finishes the word still being typed after the callsign, as a space would. Send and
    /// opening a chip call this, so `K6ABC 55` uses the 55 without a trailing space. A lone
    /// callsign is left alone, so it can still be finished where the cursor is.
    func confirmEntry() {
        guard !entryText.hasSuffix(" "),
              entryText.split(separator: " ").count > 1
        else { return }
        entryText += " "
        parseEntry()
    }

    /// Strip consumed tokens (frequency, mode, QTH, grid, park ref, summit ref, time) from
    /// entryText once they are followed by a space. A whole callsign typed after the first
    /// token is a correction: it replaces the first token in place. The callsign, RST, and
    /// unrecognized tokens stay. Pushes frequency/mode to radio when consumed.
    private func consumeTokens(_ parsed: ParsedEntry) {
        let tokens = parsed.tokens
        guard tokens.count > 1 else { return }

        let endsWithSpace = entryText.hasSuffix(" ")

        var kept: [String] = []
        var correctedCallsign: String?
        var consumedFrequency = false
        var consumedMode = false
        for (index, classified) in tokens.enumerated() {
            let isLast = index == tokens.count - 1
            let isConfirmed = !isLast || endsWithSpace

            switch classified.kind {
            case .callsign where index > 0 && isConfirmed:
                correctedCallsign = classified.text
            case .callsign, .rst, .unrecognized:
                kept.append(classified.text)
            case .frequency:
                if isConfirmed { consumedFrequency = true } else { kept.append(classified.text) }
            case .mode:
                if isConfirmed { consumedMode = true } else { kept.append(classified.text) }
            case .qth, .gridSquare, .potaRef, .sotaRef, .time:
                if !isConfirmed {
                    kept.append(classified.text)
                }
            }
        }

        if let corrected = correctedCallsign {
            if corrected.sanitizedCallsign != kept[0].sanitizedCallsign {
                clearDetailsForCorrectedCallsign()
            }
            kept[0] = corrected
        }

        var rebuilt = kept.joined(separator: " ")
        if endsWithSpace { rebuilt += " " }

        if rebuilt != entryText {
            entryText = rebuilt
        }

        if consumedFrequency || consumedMode {
            pushFrequencyToRadio()
        }
    }

    func markManualOverride(_ field: String) {
        manualOverrides.insert(field)
    }

    func hasManualOverride(_ field: String) -> Bool {
        manualOverrides.contains(field)
    }

    // MARK: - Callsign Changed (Auto-populate cascade)

    func callsignChanged() {
        lookupTask?.cancel()
        let call = parsedCallsign

        if call.isEmpty {
            clearAllFields()
            return
        }

        guard call.count >= 3 else {
            clearLookupFields()
            return
        }

        lookupTask = Task {
            // 300ms debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            // All sources fire in parallel
            async let local: Void = resolveLocal(call)
            async let worked: Void = resolveTimesWorked(call)
            async let qrz: Void = resolveQRZ(call)
            async let spot: Void = resolveSpotData(call)
            async let today: Void = resolveWorkedToday(call)
            async let dupe: Void = resolveDupe(call)
            _ = await (local, worked, qrz, spot, today, dupe)
        }
    }

    // MARK: - Lookup Sources

    /// The log, then the prefix resolver — LOW authority, only fills empty fields
    private func resolveLocal(_ call: String) async {
        if let details = try? await qsoRepo.details(forCallsign: call) {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if let n = details.name, name.isEmpty { name = n }
                if let q = details.qth, qth.isEmpty { qth = q }
                if let g = details.grid, grid == nil { grid = g }
            }
        }

        guard !Task.isCancelled else { return }

        // LOWEST authority — only fills empty qth
        if let resolved = CallsignPrefixResolver.resolve(call) {
            await MainActor.run {
                if qth.isEmpty { qth = resolved }
            }
        }
    }

    /// QRZ network lookup — HIGH authority, overwrites non-manual fields
    private func resolveQRZ(_ call: String) async {
        guard let result = await qrzLookup?.lookup(call) else { return }
        guard !Task.isCancelled else { return }

        let normalizedQTH: String?
        if let state = result.state, !state.isEmpty {
            normalizedQTH = state
        } else if let country = result.country {
            normalizedQTH = CallsignPrefixResolver.abbreviate(country)
        } else {
            normalizedQTH = nil
        }

        await MainActor.run {
            if let n = result.name, !n.isEmpty, !manualOverrides.contains("name") {
                name = n
            }
            if let q = normalizedQTH, !q.isEmpty, !manualOverrides.contains("qth") {
                qth = q
            }
            if let g = result.grid, !g.isEmpty {
                grid = g
            }
        }
    }

    /// Spot lookup — populates references (not frequency or mode)
    private func resolveSpotData(_ call: String) async {
        guard let spot = spotLookup?(call), !Task.isCancelled else { return }
        await MainActor.run {
            if let ref = spot.potaReference,
               !manualOverrides.contains("potaRef"), potaRefInput.isEmpty {
                potaRefInput = POTAPark.normalize(ref)
                validatePOTARef()
            }
            if let ref = spot.sotaReference,
               !manualOverrides.contains("sotaRef"), sotaRefInput.isEmpty {
                sotaRefInput = SOTASummit.normalize(ref)
                validateSOTARef()
            }
        }
    }

    /// Check if this callsign+band+mode+references is a duplicate within the current activation.
    /// The key is the same tuple the save writes, so the same station worked again from a
    /// different summit or park (S2S/P2P) is a new contact, not a dupe.
    private func resolveDupe(_ call: String) async {
        guard let logId = log.id else { return }
        let band = Double(frequencyText).flatMap { BandPlan.band(for: $0) }
        guard let band else {
            await MainActor.run { isDupe = false }
            return
        }
        let dupe = (try? await qsoRepo.isDuplicate(
            callsign: call.uppercased(),
            band: band,
            mode: mode,
            sotaRef: resolvedSotaRef,
            potaRef: resolvedPotaRef,
            logId: logId,
            excludingId: editingQSO?.id
        )) ?? false
        guard !Task.isCancelled else { return }
        await MainActor.run { isDupe = dupe }
    }

    /// Update frequency from radio VFO, with cooldown after app→radio push
    func updateFromRadio(frequencyMHz: Double?) {
        guard let mhz = frequencyMHz else { return }
        if let pushTime = frequencyPushTime, Date().timeIntervalSince(pushTime) < pushCooldown { return }
        let formatted = String(format: "%.3f", mhz)
        if frequencyText != formatted {
            frequencyText = formatted
            frequencyChanged()
        }
    }

    /// Push manually-edited frequency to the radio via SOTACat
    func pushFrequencyToRadio() {
        guard let service = sotaCatService, service.isConnected else { return }
        guard let freq = Double(frequencyText) else { return }
        frequencyPushTime = Date()
        modePushTime = Date()
        service.tune(frequencyMHz: freq, mode: mode)
    }

    /// Push manually-toggled mode to the radio via SOTACat
    func pushModeToRadio() {
        guard let service = sotaCatService, service.isConnected else { return }
        modePushTime = Date()
        service.setMode(mode)
    }

    /// Re-check dupe status and auto-derive mode when frequency (band) changes
    func frequencyChanged() {
        updateModeFromFrequency()
        recheckDupe()
    }

    private func recheckDupe() {
        let call = parsedCallsign
        guard call.count >= 3 else { return }
        Task {
            await resolveDupe(call)
        }
    }

    /// How many times this callsign appears in any QSO today (all logs + unattached)
    private func resolveWorkedToday(_ call: String) async {
        let today = Date().adifDate
        let count = (try? await qsoRepo.countForCallsignOnDate(call, date: today)) ?? 0
        guard !Task.isCancelled else { return }
        await MainActor.run {
            workedToday = count
        }
    }

    /// Total times this callsign has been worked, derived from the QSO table.
    private func resolveTimesWorked(_ call: String) async {
        let count = (try? await qsoRepo.countForCallsign(call)) ?? 0
        guard !Task.isCancelled else { return }
        await MainActor.run {
            timesWorked = count
        }
    }

    // MARK: - POTA P2P Validation

    /// Validates the park reference and re-runs the dupe check, since the reference is part of the dupe key.
    func validatePOTARef() {
        let normalized = potaRefInput.sanitizedAlphanumeric
        guard normalized.count >= 3 else {
            potaRefValid = false
            potaRefFormatted = nil
            potaRefName = nil
            recheckDupe()
            return
        }
        Task {
            let park = try? await refRepo.fetchParkByNormalized(normalized)
            await MainActor.run {
                potaRefValid = park != nil
                potaRefFormatted = park?.reference
                potaRefName = park?.name
                recheckDupe()
            }
        }
    }

    // MARK: - SOTA S2S Validation

    /// Validates the summit reference and re-runs the dupe check, since the reference is part of the dupe key.
    func validateSOTARef() {
        let normalized = sotaRefInput.sanitizedAlphanumeric
        guard normalized.count >= 4 else {
            sotaRefValid = false
            sotaRefFormatted = nil
            recheckDupe()
            return
        }
        Task {
            let summit = try? await refRepo.fetchSummitByNormalized(normalized)
            await MainActor.run {
                sotaRefValid = summit != nil
                sotaRefFormatted = summit?.code
                recheckDupe()
            }
        }
    }

    // MARK: - Editing

    func loadForEditing(_ qso: QSO) {
        guard !qso.syncedToQRZ else { return }
        editingQSO = qso
        entryText = qso.callsign
        rstSent = qso.rstSent
        rstReceived = qso.rstReceived
        mode = qso.mode
        if let freq = qso.frequency {
            frequencyText = String(format: "%.3f", freq)
        }
        name = qso.name ?? ""
        qth = qso.qth ?? ""
        // The saved references are where the station was, so fixing a misspelled
        // callsign keeps them. Name, QTH and grid belong to the old callsign.
        if let ref = qso.potaRef {
            potaRefInput = POTAPark.normalize(ref)
            markManualOverride("potaRef")
            validatePOTARef()
        }
        if let ref = qso.sotaRef {
            sotaRefInput = SOTASummit.normalize(ref)
            markManualOverride("sotaRef")
            validateSOTARef()
        }
        // Restore saved grid into the pill so it's visible and editable during edit.
        // The pill is the source of truth in edit mode — the hidden `grid` only carries
        // auto-populated lookups (resolveLocal/resolveQRZ).
        gridInput = qso.grid ?? ""
        timeOnInput = qso.timeOn
    }

    /// Normalizes the time pill on commit. Invalid input quietly reverts — to the
    /// original time when editing, or to empty (stamp at save) for a new QSO.
    func timeCommitted() {
        if let time = OmniFieldParser.parseTime(timeOnInput) {
            timeOnInput = time
        } else {
            timeOnInput = editingQSO?.timeOn ?? ""
        }
    }

    func cancelEditing() {
        editingQSO = nil
        clearFieldsForNextQSO()
    }

    // MARK: - Save QSO

    /// Main actor because finishing the last word writes the entry and fields the view is bound to.
    @MainActor
    func saveQSO() async {
        // Only a save that succeeds below may report a contact as saved.
        lastSavedQSO = nil
        let typedCallsign = parsedCallsign
        confirmEntry()
        let callsign = parsedCallsign
        if callsign != typedCallsign {
            // The debounced lookup never ran for a correction made on Send. Fill
            // what the log and the prefix know, which works offline and is instant.
            await resolveLocal(callsign)
        }
        guard !callsign.isEmpty, let logId = log.id else { return }

        let frequency = Double(frequencyText)
        let band = frequency.flatMap { BandPlan.band(for: $0) } ?? "20m"

        // Operator-typed grid wins. New QSO with empty input falls back to the hidden
        // auto-populated value; an empty pill during edit means the operator cleared it,
        // unless the callsign was corrected, which emptied it for the new station's lookup.
        // Invalid typed input persists as nil — ADIF GRIDSQUARE has a defined format and shouldn't carry junk.
        let resolvedGrid: String?
        if !gridInput.isEmpty {
            resolvedGrid = OmniFieldParser.parseGridSquare(gridInput)
        } else if let editing = editingQSO, callsign.uppercased() == editing.callsign.uppercased() {
            resolvedGrid = nil
        } else {
            resolvedGrid = grid
        }

        var qso: QSO
        if let editing = editingQSO {
            // Update existing QSO — preserve id and date; time comes from the pill,
            // falling back to the original when cleared or invalid
            qso = QSO(
                id: editing.id,
                logId: logId,
                callsign: callsign.uppercased(),
                date: editing.date,
                timeOn: OmniFieldParser.parseTime(timeOnInput) ?? editing.timeOn,
                frequency: frequency,
                band: band,
                mode: mode,
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                grid: resolvedGrid,
                sotaRef: resolvedSotaRef,
                potaRef: resolvedPotaRef,
                qrzLogId: editing.qrzLogId,
                syncedToQRZ: editing.syncedToQRZ
            )
        } else {
            // Create new QSO — a typed time token back-dates it within today's UTC date
            let now = Date()
            qso = QSO(
                logId: logId,
                callsign: callsign.uppercased(),
                date: now.adifDate,
                timeOn: OmniFieldParser.parseTime(timeOnInput) ?? now.adifTime,
                frequency: frequency,
                band: band,
                mode: mode,
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                grid: resolvedGrid,
                sotaRef: resolvedSotaRef,
                potaRef: resolvedPotaRef
            )
        }

        do {
            try await qsoRepo.save(&qso)
            lastSavedQSO = qso

            // Clear fields but keep frequency and mode
            await MainActor.run {
                editingQSO = nil
                saveCount += 1
                clearFieldsForNextQSO()
            }
        } catch {
            AppLog.database.error("Failed to save QSO: \(error)")
        }
    }

    // MARK: - Spot pre-fill

    func prefillFromSpot(_ spot: Spot) {
        // Clear all fields first so stale data from a previous spot doesn't persist
        clearFieldsForNextQSO()

        entryText = spot.activatorCallsign.uppercased()
        frequencyText = String(format: "%.3f", spot.frequency)
        mode = spot.mode
        rstSent = defaultRST
        rstReceived = defaultRST

        // Tapping a spot chooses its references, so correcting a misspotted callsign keeps them.
        if let ref = spot.potaReference {
            potaRefInput = POTAPark.normalize(ref)
            markManualOverride("potaRef")
            validatePOTARef()
        }
        if let ref = spot.sotaReference {
            sotaRefInput = SOTASummit.normalize(ref)
            markManualOverride("sotaRef")
            validateSOTARef()
        }
        callsignChanged()
    }

    // MARK: - Private

    private func clearAllFields() {
        rstSent = defaultRST
        rstReceived = defaultRST
        name = ""
        qth = ""
        potaRefInput = ""
        potaRefFormatted = nil
        potaRefName = nil
        potaRefValid = false
        sotaRefInput = ""
        sotaRefFormatted = nil
        sotaRefValid = false
        gridInput = ""
        timeOnInput = editingQSO?.timeOn ?? ""
        timesWorked = 0
        workedToday = 0
        isDupe = false
        grid = nil
        rstSentFromEntry = false
        rstReceivedFromEntry = false
        manualOverrides = []
        // frequency and mode persist between QSOs
    }

    /// Forgets what was looked up for the callsign, keeping anything the operator typed.
    /// The lookup for the next callsign refills the rest.
    private func clearLookupFields() {
        timesWorked = 0
        workedToday = 0
        isDupe = false
        grid = nil
        if !manualOverrides.contains("name") { name = "" }
        if !manualOverrides.contains("qth") { qth = "" }
    }

    /// A correction names a different station, so also drop the references a spot lookup
    /// filled and, when editing, the saved grid. Typed or chosen references stay.
    private func clearDetailsForCorrectedCallsign() {
        // The old callsign's lookup may still be waiting out its debounce; it must not refill
        // what is about to belong to the new station.
        lookupTask?.cancel()
        clearLookupFields()
        if !manualOverrides.contains("potaRef") {
            potaRefInput = ""
            potaRefFormatted = nil
            potaRefName = nil
            potaRefValid = false
        }
        if !manualOverrides.contains("sotaRef") {
            sotaRefInput = ""
            sotaRefFormatted = nil
            sotaRefValid = false
        }
        // When editing, the pill holds the saved grid, which belonged to the old station.
        if isEditing, gridInput == editingQSO?.grid ?? "" { gridInput = "" }
    }

    // MARK: - CW Keyer

    /// RST with cut numbers for CW keyer (9 → N)
    private var rstForKeyer: String {
        // A first RST still being typed is sent as typed, without applying it to the chip.
        let whole = OmniFieldParser.parse(entryText)
        let rstWords = whole.tokens.filter { $0.kind == .rst }
        let rst: String
        if !entryText.hasSuffix(" "), whole.tokens.last?.kind == .rst, rstWords.count == 1,
           let typed = whole.rstSent {
            rst = expandRST(typed)
        } else {
            rst = rstSent
        }
        return rst.replacingOccurrences(of: "9", with: "N")
    }

    /// The callsign the CW keys send: a correction still being typed (`K6ABC 55 W7X` sends
    /// `W7X`), else the callsign as typed. Sending never changes the entry, so a key tapped
    /// mid-call (`W7X` then `?`) leaves the cursor where it was to finish the call.
    private var callsignForKeyer: String {
        let corrections = OmniFieldParser.parse(entryText).tokens.dropFirst().filter { $0.kind == .callsign }
        return corrections.last?.text.sanitizedCallsign ?? parsedCallsign
    }

    /// Strip dashes from references for CW (slashes preserved as valid Morse prosign)
    private static func stripDashesForCW(_ ref: String) -> String {
        ref.replacingOccurrences(of: "-", with: "")
    }

    func expandTemplate(_ template: String) -> String {
        let activity: String
        if log.sotaReference != nil {
            activity = "SOTA"
        } else if log.potaReference != nil {
            activity = "POTA"
        } else {
            activity = ""
        }

        var text = template
        text = text.replacingOccurrences(of: "{myCall}", with: log.myCallsign)
        text = text.replacingOccurrences(of: "{call}", with: callsignForKeyer)
        text = text.replacingOccurrences(of: "{rst}", with: rstForKeyer)
        text = text.replacingOccurrences(of: "{mySOTA}", with: Self.stripDashesForCW(log.sotaReference ?? ""))
        text = text.replacingOccurrences(of: "{myPOTA}", with: Self.stripDashesForCW(log.potaReference ?? ""))
        text = text.replacingOccurrences(of: "{activity}", with: activity)

        // Collapse consecutive spaces and trim
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespaces)
        return text
    }

    func previewExpandTemplate(_ template: String) -> String {
        let activity: String
        if log.sotaReference != nil {
            activity = "SOTA"
        } else if log.potaReference != nil {
            activity = "POTA"
        } else {
            activity = ""
        }

        var text = template
        let substitutions: [(String, String)] = [
            ("{myCall}", log.myCallsign),
            ("{call}", callsignForKeyer),
            ("{rst}", rstForKeyer),
            ("{mySOTA}", Self.stripDashesForCW(log.sotaReference ?? "")),
            ("{myPOTA}", Self.stripDashesForCW(log.potaReference ?? "")),
            ("{activity}", activity),
        ]
        for (placeholder, value) in substitutions {
            if !value.isEmpty {
                text = text.replacingOccurrences(of: placeholder, with: value)
            }
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespaces)
        return text
    }

    func sendCWMacro(_ template: String) {
        let message = expandTemplate(template)
        guard !message.isEmpty else { return }
        Task {
            let success = await sotaCatService?.sendKeyer(message: message) ?? false
            if success {
                await MainActor.run {
                    keyerSendCount += 1
                }
            }
        }
    }

    // MARK: - Private

    private func clearFieldsForNextQSO() {
        entryText = ""
        rstSent = defaultRST
        rstReceived = defaultRST
        name = ""
        qth = ""
        potaRefInput = ""
        potaRefFormatted = nil
        potaRefName = nil
        potaRefValid = false
        sotaRefInput = ""
        sotaRefFormatted = nil
        sotaRefValid = false
        gridInput = ""
        timeOnInput = ""
        timesWorked = 0
        workedToday = 0
        isDupe = false
        grid = nil
        rstSentFromEntry = false
        rstReceivedFromEntry = false
        manualOverrides = []
        // frequency and mode persist between QSOs
    }
}
