import Foundation
import Observation

@Observable
final class SOTACatService {
    private(set) var isConnected = false
    private(set) var radioFrequency: Double?
    private(set) var radioMode: String?

    private let baseURL = "http://sotacat.local"
    private let session: URLSession
    private var monitoringTask: Task<Void, Never>?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 5
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if self.isConnected {
                    await self.pollVFO()
                } else {
                    await self.probeConnection()
                }
                let interval: Duration = self.isConnected ? .seconds(1) : .seconds(5)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    // MARK: - Tune (Pounce)

    func tune(frequencyMHz: Double, mode: String = "CW") {
        let hz = Int(frequencyMHz * 1_000_000)
        Task {
            await sendPUT("/api/v1/frequency?frequency=\(hz)")
            await sendPUT("/api/v1/mode?mode=\(mode)")
        }
    }

    // MARK: - CW Keyer

    func sendKeyer(message: String) async -> Bool {
        guard let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/v1/keyer?message=\(encoded)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 10
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...299).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Frequency Conversion

    static func hzToMHz(_ hz: Int) -> Double {
        Double(hz) / 1_000_000
    }

    static func mhzToHz(_ mhz: Double) -> Int {
        Int(mhz * 1_000_000)
    }

    // MARK: - Private

    private func probeConnection() async {
        guard let url = URL(string: "\(baseURL)/api/v1/version") else { return }
        do {
            let (_, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                await MainActor.run { isConnected = true }
            }
        } catch {
            // Not connected — expected when SOTAcat is off
        }
    }

    private func pollVFO() async {
        guard let url = URL(string: "\(baseURL)/api/v1/frequency") else { return }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                await MainActor.run {
                    isConnected = false
                    radioFrequency = nil
                    radioMode = nil
                }
                return
            }
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let hz = Int(text) {
                let mhz = SOTACatService.hzToMHz(hz)
                await MainActor.run {
                    if radioFrequency != mhz {
                        radioFrequency = mhz
                    }
                }
            }
        } catch {
            await MainActor.run {
                isConnected = false
                radioFrequency = nil
                radioMode = nil
            }
        }

        // Poll mode separately — failure is non-fatal (don't disconnect)
        await pollMode()
    }

    private func pollMode() async {
        guard let url = URL(string: "\(baseURL)/api/v1/mode") else { return }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            let mode = Self.normalizeMode(text.uppercased())
            await MainActor.run {
                if radioMode != mode {
                    radioMode = mode
                }
            }
        } catch {
            // Mode poll failure is non-fatal — don't disconnect
        }
    }

    private static func normalizeMode(_ raw: String) -> String {
        switch raw {
        case "LSB", "USB": return "SSB"
        case "CW_R": return "CW"
        default: return raw
        }
    }

    @discardableResult
    private func sendPUT(_ path: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)\(path)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 5
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...299).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}
