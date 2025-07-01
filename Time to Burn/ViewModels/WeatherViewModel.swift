import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import UserNotifications

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager
    private let notificationManager = NotificationManager.shared
    
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
    // Moon times
    @Published var moonriseTime: Date?
    @Published var moonsetTime: Date?
    
    // UV threshold monitoring
    private var lastUVThresholdAlert: Int = 0
    
    // Background refresh timer
    private var backgroundRefreshTimer: Timer?
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        Task {
            await requestAuthorizations()
            
            // Test WeatherKit connectivity
            print("WeatherViewModel: Testing WeatherKit connectivity on startup...")
            let isWeatherKitWorking = await testWeatherKitConnectivity()
            print("WeatherViewModel: WeatherKit connectivity test result: \(isWeatherKitWorking)")
        }
        
        // Start background refresh
        startBackgroundRefresh()
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
        // Refresh data when app becomes active
        Task {
            await refreshData()
        }
    }
    
    func appWillResignActive() {
        print("WeatherViewModel: App will resign active")
        // Keep background refresh running
    }
    
    func appDidEnterBackground() {
        print("WeatherViewModel: App did enter background")
        // Keep background refresh running for Live Activity updates
    }
    
    // MARK: - Private Methods
    private func requestAuthorizations() async {
        print("WeatherViewModel: Requesting authorizations")
        
        // Request notification permissions
        let notificationGranted = await notificationManager.requestNotificationPermission()
        print("WeatherViewModel: Notification permission granted: \(notificationGranted)")
        
        // Setup notification categories
        notificationManager.setupNotificationCategories()
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
    
    private func startOfWeek() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    private func endOfWeek() -> Date {
        var components = DateComponents()
        components.day = 7
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek()) ?? Date()
    }
    
    private func processHourlyData(from forecast: Forecast<HourWeather>) -> [UVData] {
        let startTime = startOfWeek()
        let endTime = endOfWeek()

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
                let newUVData = UVData(from: currentWeather)
                let previousUV = self.currentUVData?.uvIndex
                
                self.currentUVData = newUVData
                self.hourlyUVData = processedHourlyData
                self.sunriseTime = todayDayWeather?.sun.sunrise
                self.sunsetTime = todayDayWeather?.sun.sunset
                self.moonriseTime = todayDayWeather?.moon.moonrise
                self.moonsetTime = todayDayWeather?.moon.moonset
                self.lastUpdated = Date()
                self.isLoading = false
                
                // Check for UV threshold alerts
                self.checkUVThresholdAlert()
                
                print("WeatherViewModel: Weather data updated successfully")
                print("WeatherViewModel: Current UV Index: \(newUVData.uvIndex)")
                print("WeatherViewModel: Previous UV Index: \(previousUV ?? 0)")
                print("WeatherViewModel: Sunrise: \(self.sunriseTime?.description ?? "nil")")
                print("WeatherViewModel: Sunset: \(self.sunsetTime?.description ?? "nil")")
                print("WeatherViewModel: Moonrise: \(self.moonriseTime?.description ?? "nil")")
                print("WeatherViewModel: Moonset: \(self.moonsetTime?.description ?? "nil")")
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
    
    // MARK: - UV Threshold Monitoring
    private func checkUVThresholdAlert() {
        guard let currentUV = currentUVData?.uvIndex else { return }
        
        let threshold = notificationManager.notificationSettings.uvThreshold
        
        // Only send alert if UV is above threshold and we haven't already alerted for this UV level
        if currentUV >= threshold && lastUVThresholdAlert != currentUV {
            notificationManager.scheduleUVThresholdAlert(uvIndex: currentUV, threshold: threshold)
            lastUVThresholdAlert = currentUV
            print("WeatherViewModel: UV threshold alert scheduled for UV \(currentUV)")
        }
        
        // Reset alert tracking if UV drops below threshold
        if currentUV < threshold {
            lastUVThresholdAlert = 0
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
            "errorDescription": error?.localizedDescription ?? "None",
            "notificationsAuthorized": notificationManager.isAuthorized,
            "currentUVIndex": currentUVData?.uvIndex ?? 0,
            "uvThreshold": notificationManager.notificationSettings.uvThreshold
        ]
    }
    
    // MARK: - UV Data Access
    func getCurrentUVIndex() -> Int {
        return currentUVData?.uvIndex ?? 0
    }
    
    func getCurrentUVData() -> UVData? {
        return currentUVData
    }
    
    // MARK: - Background Refresh
    private func startBackgroundRefresh() {
        print("WeatherViewModel: Starting background refresh timer")
        
        // Stop existing timer if running
        stopBackgroundRefresh()
        
        // Create timer that fires every 5 minutes (300 seconds)
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            print("WeatherViewModel: Background refresh timer fired")
            Task {
                await self?.refreshData()
            }
        }
        
        // Also refresh immediately
        Task {
            await refreshData()
        }
    }
    
    private func stopBackgroundRefresh() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
    }
    
    deinit {
        // Stop timer synchronously in deinit
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
    }
} 