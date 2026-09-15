import Foundation
import HamCore

/// HamCore's QRZ lookup reads the subscriber's login and cached session key
/// through this; the values live in the app's keychain.
struct KeychainQRZCredentials: QRZCredentialStore {
    func credentials() -> (username: String, password: String)? {
        guard let username = KeychainService.load(key: .qrzUsername),
              let password = KeychainService.load(key: .qrzPassword) else {
            return nil
        }
        return (username, password)
    }

    func sessionKey() -> String? {
        KeychainService.load(key: .qrzSessionKey)
    }

    func saveSessionKey(_ key: String) {
        try? KeychainService.save(key: .qrzSessionKey, value: key)
    }
}
