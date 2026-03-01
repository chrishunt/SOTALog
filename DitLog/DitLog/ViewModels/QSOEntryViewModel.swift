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
    var lastSavedQSO: QSO?
    var saveCount: Int = 0

    /// The callsign extracted from the first token of entryText
    var parsedCallsign: String {
        let first = entryText.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        return first.sanitizedCallsign
    }

    private var lookupTask: Task<Void, Never>?

    init(database: AppDatabase, log: Log) {
        self.database = database
        self.log = log
        self.qsoRepo = QSORepository(database: database)
        self.historyRepo = CallsignHistoryRepository(database: database)
        self.refRepo = ReferenceRepository(database: database)
    }

    // MARK: - Omnifield Parsing

    func parseEntry() {
        let parsed = OmniFieldParser.parse(entryText)

        if let rst = parsed.rstSent, !manualOverrides.contains("rstSent") {
            rstSent = rst
        }
        if let rst = parsed.rstReceived, !manualOverrides.contains("rstReceived") {
            rstReceived = rst
        }
        if let freq = parsed.frequency, !manualOverrides.contains("frequency") {
            frequencyText = freq
        }
        if let q = parsed.qth, !manualOverrides.contains("qth") {
            qth = q
        }
        if let ref = parsed.potaRef, !manualOverrides.contains("potaRef") {
            potaRefInput = ref
            validatePOTARef()
        }
        if let ref = parsed.sotaRef, !manualOverrides.contains("sotaRef") {
            sotaRefInput = ref
            validateSOTARef()
        }
    }

    func markManualOverride(_ field: String) {
        manualOverrides.insert(field)
    }

    // MARK: - Callsign Changed (Auto-populate cascade)

    func callsignChanged() {
        lookupTask?.cancel()
        let call = parsedCallsign

        guard call.count >= 3 else {
            clearLookupFields()
            return
        }

        lookupTask = Task {
            // 300ms debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            // Step 1: CallsignHistory (instant, local)
            if let history = try? await historyRepo.fetch(callsign: call) {
                await MainActor.run {
                    timesWorked = history.timesWorked
                    if let n = history.name, !n.isEmpty, name.isEmpty { name = n }
                    if let q = history.qth, !q.isEmpty, qth.isEmpty { qth = q }
                }
            } else {
                await MainActor.run {
                    timesWorked = 0
                }
            }

            guard !Task.isCancelled else { return }

            // Step 3: CallsignPrefixResolver (instant, bundled)
            if qth.isEmpty {
                if let resolved = CallsignPrefixResolver.resolve(call) {
                    await MainActor.run {
                        if qth.isEmpty { qth = resolved }
                    }
                }
            }
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
        editingQSO = qso
        entryText = qso.callsign
        rstSent = qso.rstSent
        rstReceived = qso.rstReceived
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
                mode: "CW",
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
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
                mode: "CW",
                rstSent: rstSent,
                rstReceived: rstReceived,
                name: name.isEmpty ? nil : name,
                qth: qth.isEmpty ? nil : qth,
                sotaRef: sotaRefValid ? sotaRefFormatted : nil,
                potaRef: potaRefValid ? potaRefFormatted : nil
            )
        }

        do {
            try await qsoRepo.save(&qso)
            lastSavedQSO = qso

            // Update callsign history
            try? await historyRepo.recordQSO(
                callsign: qso.callsign,
                name: qso.name,
                qth: qso.qth,
                grid: nil
            )

            // Clear fields but keep frequency
            await MainActor.run {
                editingQSO = nil
                saveCount += 1
                clearFieldsForNextQSO()
            }
        } catch {
            // TODO: show error
        }
    }

    // MARK: - Spot pre-fill

    func prefillFromSpot(_ spot: Spot) {
        // Clear all fields first so stale data from a previous spot doesn't persist
        clearFieldsForNextQSO()

        entryText = spot.activatorCallsign.uppercased()
        frequencyText = String(format: "%.3f", spot.frequency)

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

    private func clearLookupFields() {
        timesWorked = 0
        name = ""
        qth = ""
    }

    private func clearFieldsForNextQSO() {
        entryText = ""
        rstSent = "599"
        rstReceived = "599"
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
        manualOverrides = []
        // frequency persists between QSOs
    }
}
