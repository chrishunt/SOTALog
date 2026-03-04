import Foundation
import Observation

@Observable
final class QSOEntryViewModel {
    private let database: AppDatabase
    private let log: Log
    private let qsoRepo: QSORepository
    private let historyRepo: CallsignHistoryRepository
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

    // Tracks which fields were manually edited (not set by omnifield)
    private var manualOverrides: Set<String> = []

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

    /// Default RST based on current mode
    var defaultRST: String {
        mode == "SSB" ? "59" : "599"
    }

    // CW Keyer
    var keyerSendCount: Int = 0

    var spotLookup: ((String) -> Spot?)?
    var qrzLookup: QRZLookupService?
    var sotaCatService: SOTACatService?

    private var lookupTask: Task<Void, Never>?
    private var grid: String?
    private var frequencyPushTime: Date?
    private var modePushTime: Date?
    private let pushCooldown: TimeInterval = 2

    init(database: AppDatabase, log: Log) {
        self.database = database
        self.log = log
        self.qsoRepo = QSORepository(database: database)
        self.historyRepo = CallsignHistoryRepository(database: database)
        self.refRepo = ReferenceRepository(database: database)
    }

    // MARK: - Mode

    /// Toggles between CW and SSB, marks as manual override, updates RST defaults
    func toggleMode() {
        mode = mode == "CW" ? "SSB" : "CW"
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
        guard upper == "CW" || upper == "SSB" else { return }
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

    func parseEntry() {
        let parsed = OmniFieldParser.parse(entryText)

        if let parsedMode = parsed.mode {
            mode = parsedMode
            markManualOverride("mode")
            updateRSTForMode()
        }

        if let rst = parsed.rstSent {
            rstSent = expandRST(rst)
            markManualOverride("rstSent")
        }
        if let rst = parsed.rstReceived {
            rstReceived = expandRST(rst)
            markManualOverride("rstReceived")
        }
        if let freq = parsed.frequency {
            frequencyText = freq
            markManualOverride("frequency")
            updateModeFromFrequency()
        }
        if let q = parsed.qth {
            qth = q
            markManualOverride("qth")
        }
        if let ref = parsed.potaRef {
            potaRefInput = ref
            markManualOverride("potaRef")
            validatePOTARef()
        }
        if let ref = parsed.sotaRef {
            sotaRefInput = ref
            markManualOverride("sotaRef")
            validateSOTARef()
        }

        consumeTokens(parsed)
    }

    /// Strip consumed tokens (frequency, mode, QTH, park ref, summit ref) from entryText
    /// once they are followed by a space. Callsign, RST, and unrecognized tokens stay.
    /// Pushes frequency/mode to radio when consumed.
    private func consumeTokens(_ parsed: ParsedEntry) {
        let tokens = parsed.tokens
        guard tokens.count > 1 else { return }

        let endsWithSpace = entryText.hasSuffix(" ")

        var kept: [String] = []
        var consumedFrequency = false
        var consumedMode = false
        for (index, classified) in tokens.enumerated() {
            let isLast = index == tokens.count - 1
            let isConfirmed = !isLast || endsWithSpace

            switch classified.kind {
            case .callsign, .rst, .unrecognized:
                kept.append(classified.text)
            case .frequency:
                if isConfirmed { consumedFrequency = true } else { kept.append(classified.text) }
            case .mode:
                if isConfirmed { consumedMode = true } else { kept.append(classified.text) }
            case .qth, .potaRef, .sotaRef:
                if !isConfirmed {
                    kept.append(classified.text)
                }
            }
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
            async let qrz: Void = resolveQRZ(call)
            async let spot: Void = resolveSpotData(call)
            async let today: Void = resolveWorkedToday(call)
            async let dupe: Void = resolveDupe(call)
            _ = await (local, qrz, spot, today, dupe)
        }
    }

    // MARK: - Lookup Sources

    /// History + prefix resolver — LOW authority, only fills empty fields
    private func resolveLocal(_ call: String) async {
        if let history = try? await historyRepo.fetch(callsign: call) {
            await MainActor.run {
                timesWorked = history.timesWorked
                if let n = history.name, !n.isEmpty, name.isEmpty { name = n }
                if let q = history.qth, !q.isEmpty, qth.isEmpty { qth = q }
                if let g = history.grid, !g.isEmpty, grid == nil { grid = g }
            }
        } else {
            await MainActor.run {
                timesWorked = 0
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
        guard let spot = spotLookup?(call) else { return }
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

    /// Check if this callsign+band+mode is a duplicate within the current activation
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

    // MARK: - POTA P2P Validation

    func validatePOTARef() {
        let normalized = potaRefInput.sanitizedAlphanumeric
        guard normalized.count >= 3 else {
            potaRefValid = false
            potaRefFormatted = nil
            potaRefName = nil
            return
        }
        Task {
            if let park = try? await refRepo.fetchParkByNormalized(normalized) {
                await MainActor.run {
                    potaRefValid = true
                    potaRefFormatted = park.reference
                    potaRefName = park.name
                }
            } else {
                await MainActor.run {
                    potaRefValid = false
                    potaRefFormatted = nil
                    potaRefName = nil
                }
            }
        }
    }

    // MARK: - SOTA S2S Validation

    func validateSOTARef() {
        let normalized = sotaRefInput.sanitizedAlphanumeric
        guard normalized.count >= 4 else {
            sotaRefValid = false
            sotaRefFormatted = nil
            return
        }
        Task {
            if let summit = try? await refRepo.fetchSummitByNormalized(normalized) {
                await MainActor.run {
                    sotaRefValid = true
                    sotaRefFormatted = summit.code
                }
            } else {
                await MainActor.run {
                    sotaRefValid = false
                    sotaRefFormatted = nil
                }
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
        if let ref = qso.potaRef {
            potaRefInput = POTAPark.normalize(ref)
            validatePOTARef()
        }
        if let ref = qso.sotaRef {
            sotaRefInput = SOTASummit.normalize(ref)
            validateSOTARef()
        }
    }

    func cancelEditing() {
        editingQSO = nil
        clearFieldsForNextQSO()
    }

    // MARK: - Save QSO

    func saveQSO() async {
        let callsign = parsedCallsign
        guard !callsign.isEmpty, let logId = log.id else { return }

        let frequency = Double(frequencyText)
        let band = frequency.flatMap { BandPlan.band(for: $0) } ?? "20m"

        let resolvedGrid = grid

        var qso: QSO
        if let editing = editingQSO {
            // Update existing QSO — preserve id, date, and timeOn
            qso = QSO(
                id: editing.id,
                logId: logId,
                callsign: callsign.uppercased(),
                date: editing.date,
                timeOn: editing.timeOn,
                frequency: frequency,
                band: band,
                mode: mode,
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                grid: resolvedGrid,
                sotaRef: sotaRefValid ? sotaRefFormatted : nil,
                potaRef: potaRefValid ? potaRefFormatted : nil,
                qrzLogId: editing.qrzLogId,
                syncedToQRZ: editing.syncedToQRZ
            )
        } else {
            // Create new QSO
            let now = Date()
            qso = QSO(
                logId: logId,
                callsign: callsign.uppercased(),
                date: now.adifDate,
                timeOn: now.adifTime,
                frequency: frequency,
                band: band,
                mode: mode,
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                grid: resolvedGrid,
                sotaRef: sotaRefValid ? sotaRefFormatted : nil,
                potaRef: potaRefValid ? potaRefFormatted : nil
            )
        }

        do {
            try await qsoRepo.save(&qso)
            lastSavedQSO = qso

            // Update callsign history
            do {
                try await historyRepo.recordQSO(
                    callsign: qso.callsign,
                    name: qso.name,
                    qth: qso.qth,
                    grid: resolvedGrid
                )
            } catch {
                AppLog.database.error("Failed to record callsign history: \(error)")
            }

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

        if let ref = spot.potaReference {
            potaRefInput = POTAPark.normalize(ref)
            validatePOTARef()
        }
        if let ref = spot.sotaReference {
            sotaRefInput = SOTASummit.normalize(ref)
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
        timesWorked = 0
        workedToday = 0
        isDupe = false
        grid = nil
        manualOverrides = []
        // frequency and mode persist between QSOs
    }

    private func clearLookupFields() {
        timesWorked = 0
        workedToday = 0
        isDupe = false
        name = ""
        qth = ""
        grid = nil
    }

    // MARK: - CW Keyer

    /// RST with cut numbers for CW keyer (9 → N)
    private var rstForKeyer: String {
        rstSent.replacingOccurrences(of: "9", with: "N")
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
        text = text.replacingOccurrences(of: "{call}", with: parsedCallsign)
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
            ("{call}", parsedCallsign),
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
        timesWorked = 0
        workedToday = 0
        isDupe = false
        grid = nil
        manualOverrides = []
        // frequency and mode persist between QSOs
    }
}
