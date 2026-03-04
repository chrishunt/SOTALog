import Foundation
import Observation

@MainActor @Observable
final class QRZSyncViewModel {
    private let database: AppDatabase
    private let qsoRepo: QSORepository
    private let logRepo: LogRepository
    private let historyRepo: CallsignHistoryRepository
    private let refRepo: ReferenceRepository

    var hasAPIKey = false
    var hasCredentials = false
    var unsyncedCount = 0
    var syncStatus: SyncStatus = .idle
    var lastSyncDate: Date?
    var adifExport: String = ""

    enum SyncStatus: Equatable {
        case idle
        case synced
        case uploading(Int, Int)        // (done, total)
        case preparingReferences        // auto-fetching POTA/SOTA ref data
        case downloading(Int)           // QSOs fetched so far
        case importing                  // writing to DB
        case error(String)
    }

    var isBusy: Bool {
        switch syncStatus {
        case .idle, .synced, .error: return false
        default: return true
        }
    }

    var isAllSynced: Bool {
        if case .synced = syncStatus { return true }
        if case .idle = syncStatus { return unsyncedCount == 0 }
        return false
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
        self.refRepo = ReferenceRepository(database: database)
    }

    func loadState() async {
        hasAPIKey = KeychainService.load(key: .qrzAPIKey) != nil
        hasCredentials = KeychainService.load(key: .qrzUsername) != nil
        unsyncedCount = (try? await qsoRepo.fetchUnsynced().count) ?? 0
        lastSyncDate = try? await qsoRepo.lastSyncDate()
        if unsyncedCount == 0, lastSyncDate != nil {
            syncStatus = .synced
        }
        await refreshADIF()
    }

    private func refreshADIF() async {
        let logs = (try? await logRepo.fetchAll()) ?? []
        let allQSOs = (try? await qsoRepo.fetchAll()) ?? []
        let qsosByLogId = Dictionary(grouping: allQSOs, by: { $0.logId })
        let sections = logs.compactMap { log -> (Log, [QSO])? in
            guard let id = log.id else { return nil }
            let qsos = qsosByLogId[id] ?? []
            return qsos.isEmpty ? nil : (log, qsos)
        }
        adifExport = ADIFFormatter.encodeFile(sections: sections)
    }

    func saveCredentials(apiKey: String, username: String, password: String) async {
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

        let unsynced: [QSO]
        do {
            unsynced = try await qsoRepo.fetchUnsynced()
        } catch {
            syncStatus = .error(error.localizedDescription)
            return
        }

        guard !unsynced.isEmpty else { return }

        syncStatus = .uploading(0, unsynced.count)

        do {
            let logs = try await logRepo.fetchAll()
            let logMap = Dictionary(uniqueKeysWithValues: logs.compactMap { log in
                log.id.map { ($0, log) }
            })

            var done = 0
            for qso in unsynced {
                let log = qso.logId.flatMap { logMap[$0] }
                let adif = ADIFFormatter.encode(qso: qso, log: log)

                if let qrzLogId = try await QRZLogbookService.uploadQSO(apiKey: apiKey, adifRecord: adif) {
                    if let qsoId = qso.id {
                        try await qsoRepo.markSynced(id: qsoId, qrzLogId: qrzLogId)
                    }
                }

                done += 1
                syncStatus = .uploading(done, unsynced.count)
            }

            unsyncedCount = 0
            syncStatus = .synced
            await refreshADIF()
        } catch {
            AppLog.sync.error("Upload failed: \(error)")
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Refresh from QRZ

    func refreshFromQRZ() async {
        guard let apiKey = KeychainService.load(key: .qrzAPIKey) else { return }

        // 0. Pre-check: ensure reference data is available
        do {
            try await ensureReferencesLoaded()
        } catch {
            AppLog.sync.error("Reference fetch failed: \(error)")
            syncStatus = .error("Failed to fetch reference data: \(error.localizedDescription)")
            return
        }

        // 1. Download phase: paginate all QSOs from QRZ
        syncStatus = .downloading(0)
        var allRecords: [[String: String]] = []

        do {
            var afterLogId: Int64 = 0
            var previousMaxLogId: Int64 = -1

            for _ in 0..<200 {
                let result = try await QRZLogbookService.downloadQSOs(apiKey: apiKey, afterLogId: afterLogId)
                let records = ADIFFormatter.decode(result.adif)
                allRecords.append(contentsOf: records)

                syncStatus = .downloading(allRecords.count)
                await Task.yield()

                if result.count < 250 { break }

                // Advance cursor using per-record APP_QRZLOG_LOGID
                let pageMaxLogId = records.compactMap { $0["APP_QRZLOG_LOGID"].flatMap(Int64.init) }.max() ?? 0
                if pageMaxLogId == 0 || pageMaxLogId == previousMaxLogId { break }
                previousMaxLogId = pageMaxLogId
                afterLogId = pageMaxLogId + 1
            }
        } catch {
            AppLog.sync.error("Download failed: \(error)")
            syncStatus = .error(error.localizedDescription)
            return
        }

        // 2. Group phase: load validation dictionaries and group records
        let validPotaRefs: [String: String]
        let validSotaCodes: [String: String]
        do {
            validPotaRefs = try await qsoRepo.loadValidPotaRefs()
            validSotaCodes = try await qsoRepo.loadValidSotaCodes()
        } catch {
            syncStatus = .error("Failed to load reference data")
            return
        }

        let fallbackCallsign = KeychainService.load(key: .qrzUsername)?.uppercased()
        let grouped = SyncImporter.groupByActivation(
            records: allRecords,
            fallbackCallsign: fallbackCallsign,
            validPotaRefs: validPotaRefs,
            validSotaCodes: validSotaCodes
        )

        // 3. Import phase: atomic write
        syncStatus = .importing
        do {
            let result = try await qsoRepo.fullRefreshImport(
                groupedQSOs: grouped.activations,
                unattachedQSOs: grouped.unattached
            )
            AppLog.sync.info("Refresh complete: \(result.importedCount) QSOs, \(result.activationsCreated) new activations, \(result.activationsReused) reused")

            // 4. Post-import
            try await historyRepo.rebuildFromQSOTable()
            try await qsoRepo.saveLastSyncedQRZLogId(0)
            lastSyncDate = Date()

            unsyncedCount = (try? await qsoRepo.fetchUnsynced().count) ?? 0
            syncStatus = unsyncedCount == 0 ? .synced : .idle
            await refreshADIF()
        } catch {
            AppLog.sync.error("Import failed: \(error)")
            syncStatus = .error(error.localizedDescription)
        }
    }

    // MARK: - Reference Data

    private func ensureReferencesLoaded() async throws {
        let potaMeta = try await refRepo.fetchMetadata(key: "potaParks")
        let sotaMeta = try await refRepo.fetchMetadata(key: "sotaSummits")

        let needsPota = (potaMeta?.recordCount ?? 0) == 0
        let needsSota = (sotaMeta?.recordCount ?? 0) == 0

        guard needsPota || needsSota else { return }

        syncStatus = .preparingReferences

        if needsPota {
            let parks = try await POTAParkService.fetchAllParks()
            try await refRepo.deleteAllParks()
            try await refRepo.importParks(parks)
            try await refRepo.saveMetadata(ReferenceMetadata(
                key: "potaParks",
                lastRefreshed: Date(),
                recordCount: parks.count
            ))
        }

        if needsSota {
            let summits = try await SOTASummitService.fetchSummits()
            try await refRepo.deleteAllSummits()
            try await refRepo.importSummits(summits)
            try await refRepo.saveMetadata(ReferenceMetadata(
                key: "sotaSummits",
                lastRefreshed: Date(),
                recordCount: summits.count
            ))
        }
    }

    // MARK: - ADIF Export (pre-computed in loadState)
}
