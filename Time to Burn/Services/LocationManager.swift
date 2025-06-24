import Foundation
import CoreLocation
import WeatherKit

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
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
    
    func getCurrentLocation() async -> CLLocation? {
        print("📍 LocationManager: getCurrentLocation called")
        
        // If we already have a location, return it
        if let location = location {
            print("✅ LocationManager: Returning cached location")
            return location
        }
        
        // Otherwise, request location and wait
        print("⏳ LocationManager: No cached location, requesting new location...")
        locationManager.requestLocation()
        
        // Wait for location update (with timeout)
        for _ in 0..<30 { // Wait up to 30 seconds
            if location != nil {
                print("✅ LocationManager: Got location after waiting")
                return location
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
        
        print("❌ LocationManager: Timeout waiting for location")
        return nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { 
            print("❌ LocationManager: No location in update")
            return 
        }
        print("📍 LocationManager: Received location update - \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Only update if significant change or first update
        if self.location == nil || self.location!.distance(from: location) > 100 {
            self.location = location
            print("✅ LocationManager: Updated location successfully")
            
            // Notify WeatherViewModel of new location
            if let weatherViewModel = weatherViewModel {
                print("🔄 LocationManager: Triggering weather data fetch...")
                Task {
                    await weatherViewModel.fetchUVData(for: location)
                }
            } else {
                print("⚠️ LocationManager: No WeatherViewModel reference")
            }
            
            // Reverse geocode to get location name
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let error = error {
                    print("❌ LocationManager: Geocoding error - \(error.localizedDescription)")
                    return
                }
                
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self?.locationName = placemark.locality ?? placemark.name ?? "Unknown Location"
                        print("📍 LocationManager: Location name updated to - \(self?.locationName ?? "unknown")")
                    }
                }
            }
        } else {
            print("ℹ️ LocationManager: Location change too small, ignoring")
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