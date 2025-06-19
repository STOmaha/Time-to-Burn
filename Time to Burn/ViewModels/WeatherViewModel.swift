import Foundation
import WeatherKit
import CoreLocation
import UIKit

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let notificationService: NotificationService
    private var backgroundUpdateTimer: Timer?
    private let locationManager = LocationManager()
    private var nextScheduledUpdate: Date?
    
    @Published var currentUVData: UVData?
    @Published var hourlyForecast: [UVData] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAuthorized = false
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    
    private var lastNotifiedUVIndex: Int?
    
    init(notificationService: NotificationService) {
        self.notificationService = notificationService
        print("WeatherViewModel: Initialized")
        
        // Set up the connection between LocationManager and WeatherViewModel
        locationManager.weatherViewModel = self
        
        // Set up notification observers for app lifecycle
        setupNotificationObservers()
        
        Task {
            await requestAuthorizations()
            await setupPeriodicUpdates()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        backgroundUpdateTimer?.invalidate()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        Task { @MainActor in
            print("WeatherViewModel: App became active")
            await setupPeriodicUpdates()
            await checkAndUpdateIfNeeded()
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("WeatherViewModel: App entered background")
        backgroundUpdateTimer?.invalidate()
        backgroundUpdateTimer = nil
    }
    
    private func setupPeriodicUpdates() async {
        print("WeatherViewModel: Setting up periodic updates")
        // Cancel any existing timer
        backgroundUpdateTimer?.invalidate()
        
        // Calculate next update time
        let nextUpdate = calculateNextUpdateTime()
        nextScheduledUpdate = nextUpdate
        print("WeatherViewModel: Next update scheduled for \(nextUpdate)")
        
        // Create a timer that fires every minute to check if we need to update
        backgroundUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndUpdateIfNeeded()
            }
        }
        RunLoop.main.add(backgroundUpdateTimer!, forMode: .common)
        
        // Also check immediately if needed
        await checkAndUpdateIfNeeded()
    }
    
    private func calculateNextUpdateTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        // If outside active hours (8 AM - 8 PM), schedule for next day 8 AM
        if hour < 8 || hour >= 20 {
            var components = DateComponents()
            components.hour = 8
            components.minute = 0
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            return calendar.nextDate(after: tomorrow, matching: components, matchingPolicy: .nextTime) ?? now
        }
        
        // Calculate next 15-minute interval
        let minutesUntilNext15 = 15 - (minute % 15)
        return calendar.date(byAdding: .minute, value: minutesUntilNext15, to: now) ?? now
    }
    
    private func checkAndUpdateIfNeeded() async {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current hour and minute
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        
        print("WeatherViewModel: Checking if update needed - Current time: \(hour):\(minute)")
        
        // Check if we're within the active hours (8 AM - 8 PM)
        guard hour >= 8 && hour < 20 else {
            print("WeatherViewModel: Outside active hours (8 AM - 8 PM)")
            return
        }
        
        // Check if we're at a 15-minute interval (0, 15, 30, 45)
        guard minute % 15 == 0 else {
            print("WeatherViewModel: Not at 15-minute interval")
            return
        }
        
        // Check if we haven't updated in the last 14 minutes
        if let lastUpdated = lastUpdated {
            let timeSinceLastUpdate = calendar.dateComponents([.minute], from: lastUpdated, to: now).minute ?? 0
            guard timeSinceLastUpdate >= 14 else {
                print("WeatherViewModel: Last update was too recent (\(timeSinceLastUpdate) minutes ago)")
                return
            }
        }
        
        print("WeatherViewModel: Initiating periodic update")
        await performFullRefresh()
    }
    
    private func performFullRefresh() async {
        print("WeatherViewModel: Starting full refresh")
        isRefreshing = true
        
        // First request a new location
        locationManager.requestLocation()
        
        // Wait briefly for location update
        try? await Task.sleep(for: .seconds(2))
        
        // Then fetch UV data if we have a location
        if let location = locationManager.location {
            print("WeatherViewModel: Got fresh location, fetching UV data")
            await fetchUVData(for: location)
        } else {
            print("WeatherViewModel: No location available after refresh attempt")
            error = NSError(domain: "WeatherViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get location"])
        }
        
        isRefreshing = false
    }
    
    private func requestAuthorizations() async {
        print("WeatherViewModel: Requesting authorizations")
        notificationService.requestNotificationPermissions()
        isAuthorized = true
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
    
    func fetchUVData(for location: CLLocation) async {
        print("WeatherViewModel: Fetching UV data for location - \(location.coordinate)")
        isLoading = true
        error = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            print("WeatherViewModel: Successfully fetched weather data")
            
            // Current UV Data
            let uvIndex = Int(weather.currentWeather.uvIndex.value)
            print("WeatherViewModel: UV Index - \(uvIndex)")
            
            currentUVData = UVData(
                uvIndex: uvIndex,
                date: Date(),
                timeToBurn: UVData.calculateTimeToBurn(uvIndex: uvIndex),
                location: location.description,
                timestamp: Date(),
                advice: UVData.getAdvice(uvIndex: uvIndex)
            )
            
            // Hourly Forecast
            let startTime = startOfDay()
            let endTime = endOfDay()
            
            let hourlyWeather = try await weatherService.weather(
                for: location,
                including: .hourly
            )
            
            let forecast = hourlyWeather
                .filter { startTime...endTime ~= $0.date }
                .map { hour in
                    UVData(
                        uvIndex: Int(hour.uvIndex.value),
                        date: hour.date
                    )
                }
            
            // Ensure we have entries for all 24 hours
            let calendar = Calendar.current
            var hour = 0
            var completeHourlyData: [UVData] = []
            
            while hour < 24 {
                let targetDate = calendar.date(byAdding: .hour, value: hour, to: startTime)!
                
                if let existingData = forecast.first(where: { calendar.isDate($0.date, equalTo: targetDate, toGranularity: .hour) }) {
                    completeHourlyData.append(existingData)
                } else {
                    // Add entry with UV index 0 for missing hours (typically night hours)
                    completeHourlyData.append(UVData(uvIndex: 0, date: targetDate))
                }
                hour += 1
            }
            
            await MainActor.run {
                self.hourlyForecast = completeHourlyData
                self.lastUpdated = Date()
                self.isLoading = false
            }
            
            // Check if we should send a notification
            let threshold = notificationService.uvAlertThreshold
            if uvIndex >= threshold && (lastNotifiedUVIndex == nil || lastNotifiedUVIndex! < threshold) {
                await notificationService.scheduleUVAlert(uvIndex: uvIndex, location: location.description)
                lastNotifiedUVIndex = uvIndex
                print("WeatherViewModel: Scheduled UV alert for index \(uvIndex)")
            } else if uvIndex < threshold {
                lastNotifiedUVIndex = nil
            }
            
        } catch {
            print("WeatherViewModel: Error fetching weather - \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func refreshData() async {
        if let location = locationManager.location {
            await fetchUVData(for: location)
        }
    }
    
    func scheduleUVNotifications() {
        // TODO: Implement notification scheduling
        // This will be implemented to send daily UV index updates
    }
    
    private func checkAndNotifyUV(uvIndex: Int) async {
        // Check if we should send a notification
        let threshold = notificationService.uvAlertThreshold
        if uvIndex >= threshold && (lastNotifiedUVIndex == nil || lastNotifiedUVIndex! < threshold) {
            await notificationService.scheduleUVAlert(uvIndex: uvIndex, location: "")
            lastNotifiedUVIndex = uvIndex
            print("WeatherViewModel: Scheduled UV alert for index \(uvIndex)")
        }
    }
} 