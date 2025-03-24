import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyReduced // Less precise but more battery efficient
        locationManager.distanceFilter = 1000 // Only update if moved more than 1km
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            print("🔸 Permission not determined yet")
        case .restricted:
            print("🔒 Permission restricted")
        case .denied:
            print("❌ Permission denied — go to Settings to enable location")
        case .authorizedAlways:
            print("✅ Authorized always")
        case .authorizedWhenInUse:
            print("✅ Authorized when in use — starting updates")
            manager.startUpdatingLocation()
        @unknown default:
            print("❓ Unknown authorization status")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if significant time has passed or significant distance changed
        if let currentLocation = self.location {
            let timeDifference = location.timestamp.timeIntervalSince(currentLocation.timestamp)
            let distanceDifference = location.distance(from: currentLocation)
            
            // Update if more than 15 minutes passed or moved more than 1km
            if timeDifference > 900 || distanceDifference > 1000 {
                self.location = location
            }
        } else {
            // First time getting location
            self.location = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
