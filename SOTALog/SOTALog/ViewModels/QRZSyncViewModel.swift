import Foundation
import Observation

@Observable
final class QRZSyncViewModel {
    private let database: AppDatabase
    private let qsoRepo: QSORepository
    private let logRepo: LogRepository

    var hasAPIKey = false
    var hasCredentials = false
    var unsyncedCount = 0
    var isUploading = false
    var isDownloading = false
    var uploadProgress = 0
    var downloadedCount: Int?
    var errorMessage: String?
    var successMessage: String?
    var adifExport: String = ""

    // Credential testing
    var isTestingCredentials = false
    var apiKeyTestResult: CredentialTestResult?
    var xmlLoginTestResult: CredentialTestResult?

    enum CredentialTestResult {
        case success
        case failure(String)
    }

    init(database: AppDatabase) {
        self.database = database
        self.qsoRepo = QSORepository(database: database)
        self.logRepo = LogRepository(database: database)
    }

    func loadState() async {
        hasAPIKey = KeychainService.load(key: .qrzAPIKey) != nil
        hasCredentials = KeychainService.load(key: .qrzUsername) != nil
        unsyncedCount = (try? await qsoRepo.fetchUnsynced().count) ?? 0
        await refreshADIF()
    }

    private func refreshADIF() async {
        var allQSOs: [QSO] = []
        let logs = try? await logRepo.fetchAll()
        for log in logs ?? [] {
            if let logId = log.id {
                let qsos = try? await qsoRepo.fetchAll(forLogId: logId)
                allQSOs.append(contentsOf: qsos ?? [])
            }
        }
        adifExport = ADIFFormatter.encodeFile(qsos: allQSOs)
    }

    func saveCredentials(apiKey: String, username: String, password: String) async {
        // Save to Keychain first (instant, offline-safe)
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

        // Test credentials
        isTestingCredentials = true
        apiKeyTestResult = nil
        xmlLoginTestResult = nil

        async let apiTest: Void = testAPIKey(apiKey)
        async let xmlTest: Void = testXMLLogin(username, password)
        _ = await (apiTest, xmlTest)

        isTestingCredentials = false
    }

    private func testAPIKey(_ apiKey: String) async {
        guard !apiKey.isEmpty else { return }
        do {
            try await QRZLogbookService.testAPIKey(apiKey: apiKey)
            apiKeyTestResult = .success
        } catch {
            apiKeyTestResult = .failure(error.localizedDescription)
        }
    }

    private func testXMLLogin(_ username: String, _ password: String) async {
        guard !username.isEmpty, !password.isEmpty else { return }
        do {
            let sessionKey = try await QRZXMLService.login(username: username, password: password)
            try? KeychainService.save(key: .qrzSessionKey, value: sessionKey)
            xmlLoginTestResult = .success
        } catch {
            xmlLoginTestResult = .failure(error.localizedDescription)
        }
    }

    var allTestsPassed: Bool {
        let apiOk = apiKeyTestResult.map { if case .success = $0 { return true } else { return false } } ?? true
        let xmlOk = xmlLoginTestResult.map { if case .success = $0 { return true } else { return false } } ?? true
        return apiOk && xmlOk
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
            await refreshADIF()
        } catch {
            AppLog.sync.error("Upload failed: \(error)")
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

            var afterLogId: Int64 = 0
            var totalImported = 0

            while true {
                let result = try await QRZLogbookService.downloadQSOs(apiKey: apiKey, afterLogId: afterLogId)
                let records = ADIFFormatter.decode(result.adif)

                var maxLogId = afterLogId
                for fields in records {
                    if let logIdStr = fields["APP_QRZ_LOGID"], let qrzLogId = Int64(logIdStr) {
                        maxLogId = max(maxLogId, qrzLogId)
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
                        totalImported += 1
                    }
                }

                downloadedCount = totalImported
                if result.count < 250 { break }
                afterLogId = maxLogId
            }

            successMessage = "Imported \(totalImported) new QSOs"
            await refreshADIF()
        } catch {
            AppLog.sync.error("Download failed: \(error)")
            errorMessage = error.localizedDescription
        }

        isDownloading = false
    }

    // MARK: - ADIF Export (pre-computed in loadState)
}
