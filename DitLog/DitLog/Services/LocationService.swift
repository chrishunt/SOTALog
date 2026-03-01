import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var currentGrid: String?
    var currentLatitude: Double?
    var currentLongitude: Double?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var errorMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        #if os(iOS)
        manager.requestWhenInUseAuthorization()
        #elseif os(macOS)
        manager.requestAlwaysAuthorization()
        #endif
    }

    func requestLocation() {
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLatitude = location.coordinate.latitude
        currentLongitude = location.coordinate.longitude
        currentGrid = MaidenheadConverter.gridSquare(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        #if os(iOS)
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
        #endif
        if manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
