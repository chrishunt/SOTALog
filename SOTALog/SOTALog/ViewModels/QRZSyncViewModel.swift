import Foundation
import Observation

@MainActor @Observable
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
    var downloadProgress: String?
    var errorMessage: String?
    var successMessage: String?
    var lastSyncDate: Date?
    var adifExport: String = ""
    var lastAction: SyncAction?

    enum SyncAction {
        case upload
        case download
    }

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
        self.historyRepo = CallsignHistoryRepository(database: database)
    }

    func loadState() async {
        hasAPIKey = KeychainService.load(key: .qrzAPIKey) != nil
        hasCredentials = KeychainService.load(key: .qrzUsername) != nil
        unsyncedCount = (try? await qsoRepo.fetchUnsynced().count) ?? 0
        lastSyncDate = try? await qsoRepo.lastSyncDate()
        await refreshADIF()
    }

    private func refreshADIF() async {
        var sections: [(Log, [QSO])] = []
        let logs = try? await logRepo.fetchAll()
        for log in logs ?? [] {
            if let logId = log.id {
                let qsos = (try? await qsoRepo.fetchAll(forLogId: logId)) ?? []
                if !qsos.isEmpty {
                    sections.append((log, qsos))
                }
            }
        }
        adifExport = ADIFFormatter.encodeFile(sections: sections)
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

        lastAction = .upload
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
                let log = qso.logId.flatMap { logMap[$0] }
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

        lastAction = .download
        isDownloading = true
        downloadProgress = "Checking..."
        errorMessage = nil
        successMessage = nil

        do {
            var afterLogId = try await qsoRepo.lastSyncedQRZLogId()
            var totalNew = 0
            var totalUpdated = 0
            var totalChecked = 0
            var previousMaxLogId: Int64 = -1

            for _ in 0..<200 {
                let result = try await QRZLogbookService.downloadQSOs(apiKey: apiKey, afterLogId: afterLogId)
                let records = ADIFFormatter.decode(result.adif)

                let pageResult = try await qsoRepo.importPage(records)
                totalChecked += result.count
                totalNew += pageResult.newCount
                totalUpdated += pageResult.updatedCount

                // Update progress
                if totalNew + totalUpdated > 0 {
                    downloadProgress = "Checking... \(totalChecked) QSOs, \(totalNew + totalUpdated) new"
                } else {
                    downloadProgress = "Checking... \(totalChecked) QSOs"
                }
                await Task.yield()

                if result.count < 250 { break }

                // Advance cursor using per-record APP_QRZLOG_LOGID (now properly parsed)
                if pageResult.maxLogId == 0 || pageResult.maxLogId == previousMaxLogId { break }
                previousMaxLogId = pageResult.maxLogId
                afterLogId = pageResult.maxLogId + 1
            }

            // Persist cursor only after full success
            let finalCursor = max(previousMaxLogId, afterLogId)
            if finalCursor > 0 {
                try await qsoRepo.saveLastSyncedQRZLogId(finalCursor)
            }
            lastSyncDate = Date()
            try await historyRepo.rebuildFromQSOTable()

            if totalNew == 0 && totalUpdated == 0 {
                successMessage = "Already up to date"
            } else {
                var parts: [String] = []
                if totalNew > 0 { parts.append("\(totalNew) new") }
                if totalUpdated > 0 { parts.append("\(totalUpdated) updated") }
                successMessage = "Imported \(parts.joined(separator: ", ")) QSOs"
            }

            unsyncedCount = (try? await qsoRepo.fetchUnsynced().count) ?? 0
            await refreshADIF()
        } catch {
            AppLog.sync.error("Download failed: \(error)")
            errorMessage = error.localizedDescription
        }

        downloadProgress = nil
        isDownloading = false
    }

    // MARK: - Reset

    func resetSync() async {
        isDownloading = true
        downloadProgress = nil
        errorMessage = nil
        successMessage = nil

        do {
            try await qsoRepo.deleteAllUnattached()
            try await qsoRepo.clearAllSyncState()
            try await qsoRepo.saveLastSyncedQRZLogId(0)
            lastSyncDate = nil
        } catch {
            AppLog.sync.error("Reset failed: \(error)")
            errorMessage = error.localizedDescription
            isDownloading = false
            return
        }

        // Trigger a fresh download
        isDownloading = false
        await downloadNew()
    }

    // MARK: - ADIF Export (pre-computed in loadState)
}
