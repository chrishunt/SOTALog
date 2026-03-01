import Foundation
import Observation

@Observable
final class QRZSyncViewModel {
    private let database: AppDatabase
    private let qsoRepo: QSORepository
    private let logRepo: LogRepository
    private let historyRepo: CallsignHistoryRepository

    var hasAPIKey = false
    var hasCredentials = false
    var unsyncedCount = 0
    var isUploading = false
    var isDownloading = false
    var uploadProgress = 0
    var downloadedCount: Int?
    var errorMessage: String?
    var successMessage: String?

    init(database: AppDatabase) {
        self.database = database
        self.qsoRepo = QSORepository(database: database)
        self.logRepo = LogRepository(database: database)
        self.historyRepo = CallsignHistoryRepository(database: database)
    }

    func loadState() async {
        hasAPIKey = KeychainService.load(key: .qrzAPIKey) != nil
        hasCredentials = KeychainService.load(key: .qrzUsername) != nil
        unsyncedCount = (try? await qsoRepo.fetchUnsynced().count) ?? 0
    }

    func saveCredentials(apiKey: String, username: String, password: String) {
        if !apiKey.isEmpty {
            try? KeychainService.save(key: .qrzAPIKey, value: apiKey)
            hasAPIKey = true
        }
        if !username.isEmpty {
            try? KeychainService.save(key: .qrzUsername, value: username)
            hasCredentials = true
        }
        if !password.isEmpty {
            try? KeychainService.save(key: .qrzPassword, value: password)
        }
    }

    // MARK: - Upload

    func uploadAll() async {
        guard let apiKey = KeychainService.load(key: .qrzAPIKey) else { return }

        isUploading = true
        uploadProgress = 0
        errorMessage = nil
        successMessage = nil

        do {
            let unsynced = try await qsoRepo.fetchUnsynced()
            let logs = try await logRepo.fetchAll()
            let logMap = Dictionary(uniqueKeysWithValues: logs.compactMap { log in
                log.id.map { ($0, log) }
            })

            for qso in unsynced {
                let log = logMap[qso.logId]
                let adif = ADIFFormatter.encode(qso: qso, log: log)

                if let qrzLogId = try await QRZLogbookService.uploadQSO(apiKey: apiKey, adifRecord: adif) {
                    if let qsoId = qso.id {
                        try await qsoRepo.markSynced(id: qsoId, qrzLogId: qrzLogId)
                    }
                }

                uploadProgress += 1
            }

            unsyncedCount = 0
            successMessage = "Uploaded \(uploadProgress) QSOs"
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploading = false
    }

    // MARK: - Download

    func downloadNew() async {
        guard let apiKey = KeychainService.load(key: .qrzAPIKey) else { return }

        isDownloading = true
        downloadedCount = nil
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await QRZLogbookService.downloadQSOs(apiKey: apiKey)
            let records = ADIFFormatter.decode(result.adif)

            // For downloads, we need a log to attach them to
            // Create or find a "QRZ Import" log
            var importLog: Log
            let allLogs = try await logRepo.fetchAll()
            if let existing = allLogs.first(where: { $0.notes == "QRZ Import" }) {
                importLog = existing
            } else {
                importLog = Log(
                    date: Date().adifDate,
                    myCallsign: KeychainService.load(key: .myCallsign) ?? "IMPORT",
                    notes: "QRZ Import"
                )
                try await logRepo.save(&importLog)
            }

            guard let logId = importLog.id else { return }

            var imported = 0
            for fields in records {
                // Check for duplicate via LOGID field
                if let logIdStr = fields["APP_QRZ_LOGID"], let qrzLogId = Int64(logIdStr) {
                    if try await qsoRepo.existsWithQRZLogId(qrzLogId) {
                        continue
                    }
                }

                if var qso = ADIFFormatter.qsoFromFields(fields, logId: logId) {
                    qso.syncedToQRZ = true
                    if let logIdStr = fields["APP_QRZ_LOGID"] {
                        qso.qrzLogId = Int64(logIdStr)
                    }
                    try await qsoRepo.save(&qso)
                    imported += 1
                }
            }

            downloadedCount = imported
            successMessage = "Imported \(imported) new QSOs"
        } catch {
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }

    // MARK: - ADIF Export

    func exportADIF() -> String {
        // Synchronous for ShareLink — fetch all QSOs
        var allQSOs: [QSO] = []
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            let logs = try? await logRepo.fetchAll()
            for log in logs ?? [] {
                if let logId = log.id {
                    let qsos = try? await qsoRepo.fetchAll(forLogId: logId)
                    allQSOs.append(contentsOf: qsos ?? [])
                }
            }
            semaphore.signal()
        }

        semaphore.wait()
        return ADIFFormatter.encodeFile(qsos: allQSOs)
    }

    // MARK: - QRZ XML Lookup

    func lookupCallsign(_ callsign: String) async -> QRZCallsignResult? {
        guard let username = KeychainService.load(key: .qrzUsername),
              let password = KeychainService.load(key: .qrzPassword) else {
            return nil
        }

        do {
            // Try with cached session key first
            var sessionKey = KeychainService.load(key: .qrzSessionKey)

            if sessionKey == nil {
                sessionKey = try await QRZXMLService.login(username: username, password: password)
                try? KeychainService.save(key: .qrzSessionKey, value: sessionKey!)
            }

            do {
                let result = try await QRZXMLService.lookup(callsign: callsign, sessionKey: sessionKey!)
                // Cache result
                try? await historyRepo.updateFromLookup(
                    callsign: callsign,
                    name: result.name,
                    qth: result.qth,
                    grid: result.grid
                )
                return result
            } catch QRZXMLService.QRZXMLError.sessionExpired {
                // Re-authenticate
                sessionKey = try await QRZXMLService.login(username: username, password: password)
                try? KeychainService.save(key: .qrzSessionKey, value: sessionKey!)
                let result = try await QRZXMLService.lookup(callsign: callsign, sessionKey: sessionKey!)
                try? await historyRepo.updateFromLookup(
                    callsign: callsign,
                    name: result.name,
                    qth: result.qth,
                    grid: result.grid
                )
                return result
            }
        } catch {
            return nil
        }
    }
}
