import Foundation
import CoreLocation
import WeatherKit

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationName: String = "Loading..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Add delegate for weather updates
    weak var weatherViewModel: WeatherViewModel?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update if moved 100 meters
        print("LocationManager: Initialized")
        
        // Check initial authorization status
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func requestLocation() {
        print("LocationManager: Requesting location")
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("LocationManager: Received location update - \(location.coordinate)")
        
        // Only update if significant change or first update
        if self.location == nil || self.location!.distance(from: location) > 100 {
            self.location = location
            
            // Notify WeatherViewModel of new location
            if let weatherViewModel = weatherViewModel {
                Task {
                    await weatherViewModel.fetchUVData(for: location)
                }
            }
            
            // Reverse geocode to get location name
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let error = error {
                    print("LocationManager: Geocoding error - \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self?.locationName = placemark.locality ?? placemark.name ?? "Unknown Location"
                        print("LocationManager: Location name updated to - \(self?.locationName ?? "unknown")")
                    }
                }
            }
        }
        
        // Stop updating location after receiving it
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager: Failed with error - \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("LocationManager: Authorization status changed to - \(manager.authorizationStatus.rawValue)")
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("LocationManager: Location access denied")
        case .notDetermined:
            print("LocationManager: Location access not determined")
        @unknown default:
            print("LocationManager: Unknown authorization status")
        }
    }
} 