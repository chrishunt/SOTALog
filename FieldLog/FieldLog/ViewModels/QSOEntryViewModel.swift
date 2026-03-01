import Foundation
import Observation

@Observable
final class QSOEntryViewModel {
    private let database: AppDatabase
    private let log: Log
    private let qsoRepo: QSORepository
    private let historyRepo: CallsignHistoryRepository
    private let refRepo: ReferenceRepository

    // Field state
    var callsign: String = ""
    var rstSent: String = "599"
    var rstReceived: String = "599"
    var frequencyText: String = "14.060"
    var name: String = ""
    var qth: String = ""
    var potaRef: String = ""
    var potaRefName: String?
    var potaRefValid: Bool = false
    var sotaRefInput: String = ""
    var sotaRefFormatted: String?
    var sotaRefValid: Bool = false

    // Lookup state
    var timesWorked: Int = 0
    var lastSavedQSO: QSO?
    var saveCount: Int = 0

    private var lookupTask: Task<Void, Never>?

    init(database: AppDatabase, log: Log) {
        self.database = database
        self.log = log
        self.qsoRepo = QSORepository(database: database)
        self.historyRepo = CallsignHistoryRepository(database: database)
        self.refRepo = ReferenceRepository(database: database)
    }

    // MARK: - Callsign Changed (Auto-populate cascade)

    func callsignChanged() {
        lookupTask?.cancel()
        let call = callsign

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
        let ref = potaRef.uppercased()
        guard ref.count >= 3 else {
            potaRefValid = false
            potaRefName = nil
            return
        }
        Task {
            if let park = try? await refRepo.fetchPark(reference: ref) {
                await MainActor.run {
                    potaRefValid = true
                    potaRefName = park.name
                }
            } else {
                await MainActor.run {
                    potaRefValid = false
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

    // MARK: - Save QSO

    func saveQSO() async {
        guard !callsign.isEmpty, let logId = log.id else { return }

        let now = Date()
        let frequency = Double(frequencyText)
        let band = frequency.flatMap { BandPlan.band(for: $0) } ?? "20m"

        var qso = QSO(
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
            potaRef: potaRefValid ? potaRef.uppercased() : nil
        )

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
                saveCount += 1
                clearFieldsForNextQSO()
            }
        } catch {
            // TODO: show error
        }
    }

    // MARK: - Spot pre-fill

    func prefillFromSpot(callsign: String, frequency: Double?, reference: String?, source: Spot.Source?) {
        self.callsign = callsign.uppercased()
        if let freq = frequency {
            self.frequencyText = String(format: "%.3f", freq)
        }
        if let ref = reference {
            if source == .pota {
                self.potaRef = ref
                validatePOTARef()
            } else if source == .sota {
                self.sotaRefInput = SOTASummit.normalize(ref)
                validateSOTARef()
            }
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
        callsign = ""
        rstSent = "599"
        rstReceived = "599"
        name = ""
        qth = ""
        potaRef = ""
        potaRefName = nil
        potaRefValid = false
        sotaRefInput = ""
        sotaRefFormatted = nil
        sotaRefValid = false
        timesWorked = 0
        // frequency persists between QSOs
    }
}
