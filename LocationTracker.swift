import CoreLocation
import Combine

struct DashLocation {
    let lat: Double
    let lon: Double
    let speedMps: Double
    let timestamp: Date

    var speedKmh: Double { max(0, speedMps) * 3.6 }
}

final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var current: DashLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    var onUpdate: ((DashLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 5 // meters
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let dashLoc = DashLocation(
            lat: loc.coordinate.latitude,
            lon: loc.coordinate.longitude,
            speedMps: loc.speed,
            timestamp: loc.timestamp
        )
        current = dashLoc
        onUpdate?(dashLoc)
    }
}
/// keem tya beese 
