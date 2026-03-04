import Foundation
import CoreLocation
import WeatherKit

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationName: String = "Loading..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Track if we're forcing a refresh
    private var isForceRefreshing = false
    
    // Track last synced location for significant change detection
    private var lastSignificantLocation: CLLocation?
    
    // Significant location change threshold (5km)
    private let significantDistanceThreshold: Double = 5000 // 5km in meters
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update if moved 100 meters

        // Check initial authorization status (don't request automatically - let onboarding handle it)
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
        // Note: Don't request authorization here - it will be requested during onboarding
        // when the user explicitly taps "Allow Location"
    }
    
    func requestLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /// Force a fresh location update regardless of distance
    func forceRefreshLocation() {
        print("📍 [LocationManager] 🔄 Force refreshing location...")
        isForceRefreshing = true
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            // Temporarily set distance filter to 0 to get any location update
            locationManager.distanceFilter = 0
            locationManager.startUpdatingLocation()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func getCurrentLocation() async -> CLLocation? {
        // If we already have a location, return it
        if let location = location {
            return location
        }
        
        // Otherwise, request location and wait
        locationManager.requestLocation()
        
        // Wait for location update (with timeout)
        for _ in 0..<30 { // Wait up to 30 seconds
            if location != nil {
                return location
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
        
        return nil
    }
    
    /// Debug method to test location refresh
    func debugLocationStatus() {
        print("📍 [LocationManager] 🔍 Debug Location Status:")
        print("   📍 Current Location: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")
        print("   📍 Location Name: \(locationName)")
        print("   📍 Authorization Status: \(authorizationStatus.rawValue)")
        print("   📍 Is Force Refreshing: \(isForceRefreshing)")
        print("   📍 Distance Filter: \(locationManager.distanceFilter)")
        print("   ──────────────────────────────────────")
    }
    
    // MARK: - Significant Location Change Detection
    
    /// Check if user moved significantly from last tracked location (>5km)
    func hasMovedSignificantly(from newLocation: CLLocation) -> Bool {
        guard let lastLocation = lastSignificantLocation else {
            // First location is always significant
            lastSignificantLocation = newLocation
            return true
        }
        
        let distance = newLocation.distance(from: lastLocation)
        let hasMoved = distance > significantDistanceThreshold
        
        if hasMoved {
            print("📍 [LocationManager] 🚗 Significant movement detected: \(Int(distance/1000))km")
            lastSignificantLocation = newLocation
        }
        
        return hasMoved
    }
    
    /// Get distance from last significant location
    func distanceFromLastSignificantLocation(_ newLocation: CLLocation) -> Double? {
        guard let lastLocation = lastSignificantLocation else {
            return nil
        }
        return newLocation.distance(from: lastLocation)
    }
    
    /// Update last significant location (call after successful sync)
    func updateLastSignificantLocation(_ newLocation: CLLocation) {
        lastSignificantLocation = newLocation
        print("📍 [LocationManager] ✅ Updated last significant location")
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { 
            return 
        }
        
        print("📍 [LocationManager] 📍 Location received: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // If forcing refresh, always update location
        if isForceRefreshing {
            print("📍 [LocationManager] 🔄 Force refresh: updating location")
            self.location = location
            isForceRefreshing = false
            
            // Reset distance filter back to normal
            manager.distanceFilter = 100
            
            // Store location for widget in shared UserDefaults
            let userDefaults = UserDefaults(suiteName: "group.com.anvilheadstudios.timetoburn")
            let locationData: [String: Double] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
            userDefaults?.set(locationData, forKey: "widgetLastKnownLocation")
            
            // Reverse geocode to get location name
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self?.locationName = placemark.locality ?? placemark.name ?? "Unknown Location"
                        print("📍 [LocationManager] 📍 Location name resolved: \(self?.locationName ?? "Unknown")")
                        // NOTE: Weather refresh is now controlled by WeatherViewModel, not triggered automatically here
                        // This prevents cascade loops where location→weather→location→weather...
                    }
                }
            }

            // Stop updating location after receiving it
            manager.stopUpdatingLocation()
            return
        }

        // Only update if significant change or first update (normal behavior)
        if self.location == nil || self.location!.distance(from: location) > 100 {
            self.location = location

            // Store location for widget in shared UserDefaults
            let userDefaults = UserDefaults(suiteName: "group.com.anvilheadstudios.timetoburn")
            let locationData: [String: Double] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
            userDefaults?.set(locationData, forKey: "widgetLastKnownLocation")

            // Reverse geocode to get location name
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self?.locationName = placemark.locality ?? placemark.name ?? "Unknown Location"
                        print("📍 [LocationManager] 📍 Location name resolved: \(self?.locationName ?? "Unknown")")
                        // NOTE: Weather refresh is now controlled by WeatherViewModel, not triggered automatically here
                        // This prevents cascade loops where location→weather→location→weather...
                    }
                }
            }

            // Stop updating location after receiving it
            manager.stopUpdatingLocation()
        } else {
            print("📍 [LocationManager] ⏭️  Location update skipped (insignificant change)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        
        // Reset force refresh flag on error
        isForceRefreshing = false
        
        // Reset distance filter back to normal
        manager.distanceFilter = 100
        
        // Handle specific location errors
        switch nsError.code {
        case 0: // kCLErrorLocationUnknown
            print("📍 [LocationManager] ⚠️  Location temporarily unavailable (this is normal)")
            // Don't treat this as a fatal error - location will be retried
            return
        case 1: // kCLErrorDenied
            print("📍 [LocationManager] ❌ Location access denied by user")
        case 2: // kCLErrorNetwork
            print("📍 [LocationManager] ❌ Network error getting location")
        default:
            print("📍 [LocationManager] ❌ Location Error:")
            print("   💥 Error: \(error.localizedDescription)")
            print("   🔍 Domain: \(nsError.domain)")
            print("   🔢 Code: \(nsError.code)")
        }
        print("   ──────────────────────────────────────")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("LocationManager: Access denied")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
} 