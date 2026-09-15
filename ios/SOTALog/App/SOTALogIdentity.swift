import Foundation
import HamCore

/// How SOTA Log identifies itself to HamCore and, through it, to the SOTA,
/// POTA and QRZ services and to ADIF readers.
enum SOTALogIdentity {
    static let name = "SOTA Log"

    /// The marketing version from the bundle, or "dev" outside an app bundle
    /// (such as under `swift test`).
    static let version: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    /// The User-Agent the services see, as the SOTA API terms require.
    static let userAgent = "\(name)/\(version)"
}

extension APIClient {
    /// The one client the app uses for every HamCore network service.
    static let sotaLog = APIClient(userAgent: SOTALogIdentity.userAgent)
}

extension ADIFFormatter.Software {
    /// What ADIF exports record as `PROGRAMID` and `PROGRAMVERSION`.
    static let sotaLog = ADIFFormatter.Software(name: SOTALogIdentity.name, version: SOTALogIdentity.version)
}
