import Foundation

final class QRZLookupService {
    private let historyRepo: CallsignHistoryRepository
    private var sessionKey: String?

    init(historyRepo: CallsignHistoryRepository) {
        self.historyRepo = historyRepo
    }

    func lookup(_ callsign: String) async -> QRZCallsignResult? {
        guard let username = KeychainService.load(key: .qrzUsername),
              let password = KeychainService.load(key: .qrzPassword) else {
            return nil
        }

        do {
            // Try in-memory key, then Keychain cached key, then login
            if sessionKey == nil {
                sessionKey = KeychainService.load(key: .qrzSessionKey)
            }
            if sessionKey == nil {
                sessionKey = try await QRZXMLService.login(username: username, password: password)
                try? KeychainService.save(key: .qrzSessionKey, value: sessionKey!)
            }

            do {
                let result = try await QRZXMLService.lookup(callsign: callsign, sessionKey: sessionKey!)
                try? await cacheResult(callsign: callsign, result: result)
                return result
            } catch QRZXMLService.QRZXMLError.sessionExpired {
                sessionKey = try await QRZXMLService.login(username: username, password: password)
                try? KeychainService.save(key: .qrzSessionKey, value: sessionKey!)
                let result = try await QRZXMLService.lookup(callsign: callsign, sessionKey: sessionKey!)
                try? await cacheResult(callsign: callsign, result: result)
                return result
            }
        } catch {
            AppLog.network.error("QRZ lookup failed for \(callsign): \(error)")
            return nil
        }
    }

    private func cacheResult(callsign: String, result: QRZCallsignResult) async throws {
        let normalizedQTH: String?
        if let state = result.state, !state.isEmpty {
            normalizedQTH = state
        } else if let country = result.country {
            normalizedQTH = CallsignPrefixResolver.abbreviate(country)
        } else {
            normalizedQTH = nil
        }

        try await historyRepo.updateFromLookup(
            callsign: callsign,
            name: result.name,
            qth: normalizedQTH,
            grid: result.grid
        )
    }
}
