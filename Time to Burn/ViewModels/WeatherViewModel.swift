import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager
    
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastUpdated: Date?
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    // UV Data
    @Published var currentUVData: UVData?
    @Published var hourlyUVData: [UVData] = []
    
    // Sun times
    @Published var sunriseTime: Date?
    @Published var sunsetTime: Date?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        Task {
            await requestAuthorizations()
            
            // Test WeatherKit connectivity
            print("WeatherViewModel: Testing WeatherKit connectivity on startup...")
            let isWeatherKitWorking = await testWeatherKitConnectivity()
            print("WeatherViewModel: WeatherKit connectivity test result: \(isWeatherKitWorking)")
        }
    }
    
    // MARK: - Public Methods
    func refreshData() async {
        print("WeatherViewModel: refreshData() called")
        guard let location = locationManager.location else {
            print("WeatherViewModel: No location available for refresh")
            return
        }
        
        print("WeatherViewModel: Starting weather data fetch...")
        await fetchUVData(for: location)
    }
    
    func appBecameActive() {
        print("WeatherViewModel: App became active")
    }
    
    // MARK: - Private Methods
    private func requestAuthorizations() async {
        print("WeatherViewModel: Requesting authorizations")
        print("WeatherViewModel: Notifications permission requested")
    }
    
    private func startOfDay() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private func endOfDay() -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay()) ?? Date()
    }
    
    private func processHourlyData(from forecast: Forecast<HourWeather>) -> [UVData] {
        let startTime = startOfDay()
        let endTime = endOfDay()

        return forecast
            .filter { startTime...endTime ~= $0.date }
            .map { UVData(from: $0) }
    }
    
    func fetchUVData(for location: CLLocation) async {
        print("WeatherViewModel: Fetching UV data for location - \(location.coordinate)")
        print("WeatherViewModel: WeatherService shared instance: \(weatherService)")
        print("WeatherViewModel: iOS version: \(UIDevice.current.systemVersion)")
        print("WeatherViewModel: App bundle identifier: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            print("WeatherViewModel: Attempting WeatherKit request...")
            let (currentWeather, hourlyForecast, dailyForecast) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)
            
            let todayDayWeather = dailyForecast.first
            
            let processedHourlyData = processHourlyData(from: hourlyForecast)
            
            await MainActor.run {
                self.currentUVData = UVData(from: currentWeather)
                self.hourlyUVData = processedHourlyData
                self.sunriseTime = todayDayWeather?.sun.sunrise
                self.sunsetTime = todayDayWeather?.sun.sunset
                self.lastUpdated = Date()
                self.isLoading = false
                
                print("WeatherViewModel: Weather data updated successfully")
                print("WeatherViewModel: Current UV Index: \(self.currentUVData?.uvIndex ?? 0)")
                print("WeatherViewModel: Sunrise: \(self.sunriseTime?.description ?? "nil")")
                print("WeatherViewModel: Sunset: \(self.sunsetTime?.description ?? "nil")")
                print("WeatherViewModel: Last Updated: \(self.lastUpdated?.description ?? "nil")")
            }
            
        } catch {
            print("WeatherViewModel: Error fetching weather - \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.errorMessage = "WeatherKit Error: \(error.localizedDescription)\nDomain: \((error as NSError).domain)\nCode: \((error as NSError).code)"
                self.showErrorAlert = true
            }
        }
    }
    
    // Add method to test WeatherKit connectivity
    func testWeatherKitConnectivity() async -> Bool {
        print("WeatherViewModel: Testing WeatherKit connectivity")
        
        guard let location = locationManager.location else {
            print("WeatherViewModel: No location available for connectivity test")
            return false
        }
        
        do {
            // Try a simple weather request
            print("WeatherViewModel: Testing basic WeatherKit access...")
            _ = try await weatherService.weather(for: location)
            print("WeatherViewModel: WeatherKit connectivity test successful")
            return true
        } catch {
            print("WeatherViewModel: WeatherKit connectivity test failed - \(error)")
            print("WeatherViewModel: Error details - Domain: \((error as NSError).domain), Code: \((error as NSError).code)")
            return false
        }
    }
    
    // MARK: - Diagnostic Methods
    func getDiagnosticInfo() -> [String: Any] {
        return [
            "hasLocation": locationManager.location != nil,
            "locationName": locationManager.locationName,
            "lastUpdated": lastUpdated?.description ?? "Never",
            "hasError": error != nil,
            "errorDescription": error?.localizedDescription ?? "None"
        ]
    }
} 