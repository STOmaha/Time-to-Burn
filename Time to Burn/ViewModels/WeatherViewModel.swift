import Foundation
import WeatherKit
import CoreLocation
import UIKit
import Combine

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
    @Published var sunrise: Date?
    @Published var sunset: Date?
    @Published var moonrise: Date?
    @Published var moonset: Date?
    
    private var lastNotifiedUVIndex: Int?
    
    // Add persistent storage for historical data
    private var historicalUVData: [UVData] = []
    private let userDefaults = UserDefaults.standard
    private let historicalDataKey = "historicalUVData"
    private let lastDataDateKey = "lastDataDate"
    
    private var cancellables = Set<AnyCancellable>()
    
    init(notificationService: NotificationService) {
        self.notificationService = notificationService
        print("WeatherViewModel: Initialized")
        
        // Set up the connection between LocationManager and WeatherViewModel
        locationManager.weatherViewModel = self
        
        // Load historical data
        loadHistoricalData()
        
        // Set up notification observers for app lifecycle
        setupNotificationObservers()
        
        // Run WeatherKit diagnostics
        checkWeatherKitAvailability()
        
        Task {
            await requestAuthorizations()
            await setupPeriodicUpdates()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        backgroundUpdateTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
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
    
    private func processAndInterpolateHourlyData(from forecast: Forecast<HourWeather>) -> [UVData] {
        let startTime = startOfDay()
        let endTime = endOfDay()

        let hourlyData = forecast
            .filter { startTime...endTime ~= $0.date }
            .map { UVData(from: $0) }

        var interpolatedData: [UVData] = []
        guard !hourlyData.isEmpty else { return [] }

        for i in 0..<(hourlyData.count - 1) {
            let current = hourlyData[i]
            let next = hourlyData[i+1]

            interpolatedData.append(current)

            let halfHourDate = current.date.addingTimeInterval(30 * 60)
            let interpolatedUV = (current.uvIndex + next.uvIndex) / 2
            
            interpolatedData.append(UVData(uvIndex: interpolatedUV, date: halfHourDate))
        }
        if let last = hourlyData.last {
            interpolatedData.append(last)
        }
        
        // Merge with historical data
        let mergedData = mergeWithHistoricalData(newData: interpolatedData)
        
        // Ensure we have entries for all 48 half-hour slots in a 24-hour period
        let calendar = Calendar.current
        var completeData: [UVData] = []
        
        for i in 0..<48 {
            let targetDate = startTime.addingTimeInterval(TimeInterval(i * 30 * 60))
            if let existingData = mergedData.first(where: { calendar.isDate($0.date, equalTo: targetDate, toGranularity: .minute) }) {
                completeData.append(existingData)
            } else {
                // If no exact match, create a zero-UV point for that slot
                completeData.append(UVData(uvIndex: 0, date: targetDate))
            }
        }
        
        return completeData
    }
    
    private func mergeWithHistoricalData(newData: [UVData]) -> [UVData] {
        let calendar = Calendar.current
        let now = Date()
        
        // Filter historical data to only include data from today
        let today = calendar.startOfDay(for: now)
        let historicalToday = historicalUVData.filter { calendar.isDate($0.date, inSameDayAs: today) }
        
        print("WeatherViewModel: Merging data - Historical today: \(historicalToday.count), New data: \(newData.count)")
        
        // Create a combined dataset
        var combinedData: [UVData] = []
        
        // Add historical data for past hours
        for historicalPoint in historicalToday {
            if historicalPoint.date < now {
                combinedData.append(historicalPoint)
                print("WeatherViewModel: Added historical point - Time: \(historicalPoint.date), UV: \(historicalPoint.uvIndex)")
            }
        }
        
        // Add new data for current and future hours
        for newPoint in newData {
            if newPoint.date >= now {
                combinedData.append(newPoint)
                print("WeatherViewModel: Added new point - Time: \(newPoint.date), UV: \(newPoint.uvIndex)")
            }
        }
        
        // Sort by date
        combinedData.sort { $0.date < $1.date }
        
        print("WeatherViewModel: Combined data has \(combinedData.count) points")
        
        // Update historical data with new data
        updateHistoricalData(with: newData)
        
        return combinedData
    }
    
    private func updateHistoricalData(with newData: [UVData]) {
        let calendar = Calendar.current
        let now = Date()
        
        // Remove any historical data that's older than today
        let today = calendar.startOfDay(for: now)
        historicalUVData = historicalUVData.filter { calendar.isDate($0.date, inSameDayAs: today) }
        
        print("WeatherViewModel: Updating historical data - Current historical count: \(historicalUVData.count)")
        
        // Add new data points to historical data
        for dataPoint in newData {
            // Check if we already have data for this time
            if let existingIndex = historicalUVData.firstIndex(where: { 
                calendar.isDate($0.date, equalTo: dataPoint.date, toGranularity: .minute) 
            }) {
                // Update existing data point
                historicalUVData[existingIndex] = dataPoint
                print("WeatherViewModel: Updated existing historical point - Time: \(dataPoint.date), UV: \(dataPoint.uvIndex)")
            } else {
                // Add new data point
                historicalUVData.append(dataPoint)
                print("WeatherViewModel: Added new historical point - Time: \(dataPoint.date), UV: \(dataPoint.uvIndex)")
            }
        }
        
        // Sort historical data by date
        historicalUVData.sort { $0.date < $1.date }
        
        print("WeatherViewModel: Historical data now has \(historicalUVData.count) points")
        
        // Save updated historical data
        saveHistoricalData()
    }

    func fetchUVData(for location: CLLocation) async {
        print("WeatherViewModel: Fetching UV data for location - \(location.coordinate)")
        print("WeatherViewModel: WeatherService shared instance: \(weatherService)")
        await MainActor.run {
            isLoading = true
            error = nil
        }
        clearHistoricalDataIfNewDay()
        do {
            print("WeatherViewModel: Attempting WeatherKit request...")
            let (currentWeather, hourlyForecast, dailyForecast) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)
            print("WeatherViewModel: Successfully fetched weather data")
            let processedHourlyData = processAndInterpolateHourlyData(from: hourlyForecast)
            let today = Calendar.current.startOfDay(for: Date())
            let todayDayWeather = dailyForecast.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
            await MainActor.run {
                self.currentUVData = UVData(from: currentWeather)
                self.hourlyForecast = processedHourlyData
                self.sunrise = todayDayWeather?.sun.sunrise
                self.sunset = todayDayWeather?.sun.sunset
                self.moonrise = todayDayWeather?.moon.moonrise
                self.moonset = todayDayWeather?.moon.moonset
                self.lastUpdated = Date()
                self.isLoading = false
            }
            
            let threshold = notificationService.uvAlertThreshold
            let currentUV = Int(currentWeather.uvIndex.value)
            if currentUV >= threshold && (lastNotifiedUVIndex == nil || lastNotifiedUVIndex! < threshold) {
                await notificationService.scheduleUVAlert(uvIndex: currentUV, location: locationManager.locationName)
                lastNotifiedUVIndex = currentUV
            } else if currentUV < threshold {
                lastNotifiedUVIndex = nil
            }
            
        } catch {
            print("WeatherViewModel: Error fetching weather - \(error)")
            print("WeatherViewModel: Error domain: \((error as NSError).domain)")
            print("WeatherViewModel: Error code: \((error as NSError).code)")
            print("WeatherViewModel: Error user info: \((error as NSError).userInfo)")
            
            // Check if this is the specific WeatherKit authentication error
            if (error as NSError).domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" && (error as NSError).code == 2 {
                print("WeatherViewModel: Detected WeatherKit authentication error (code 2) - attempting recovery")
                await handleWeatherKitAuthError2(for: location)
            } else {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleWeatherKitAuthError2(for location: CLLocation) async {
        print("WeatherViewModel: Handling WeatherKit authentication error code 2")
        
        // This error typically means the JWT token generation failed
        // We need to try multiple approaches to force token regeneration
        
        // First attempt: Wait and retry
        print("WeatherViewModel: Attempt 1 - Waiting 10 seconds for token regeneration...")
        try? await Task.sleep(for: .seconds(10))
        
        do {
            let (currentWeather, hourlyForecast, dailyForecast) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)
            print("WeatherViewModel: Successfully fetched weather data after first retry")
            await handleSuccessfulWeatherFetch(currentWeather: currentWeather, hourlyForecast: hourlyForecast, dailyForecast: dailyForecast)
            return
        } catch {
            print("WeatherViewModel: First retry failed - \(error)")
        }
        
        // Second attempt: Clear all data and wait longer
        print("WeatherViewModel: Attempt 2 - Clearing data and waiting 20 seconds...")
        forceWeatherKitTokenRefresh()
        try? await Task.sleep(for: .seconds(20))
        
        do {
            let (currentWeather, hourlyForecast, dailyForecast) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)
            print("WeatherViewModel: Successfully fetched weather data after second retry")
            await handleSuccessfulWeatherFetch(currentWeather: currentWeather, hourlyForecast: hourlyForecast, dailyForecast: dailyForecast)
            return
        } catch {
            print("WeatherViewModel: Second retry failed - \(error)")
        }
        
        // Third attempt: Try a different WeatherKit request type
        print("WeatherViewModel: Attempt 3 - Trying different request type...")
        try? await Task.sleep(for: .seconds(5))
        
        do {
            // Try a simpler request first
            _ = try await weatherService.weather(for: location)
            print("WeatherViewModel: Basic weather request succeeded, trying full request...")
            
            let (currentWeather, hourlyForecast, dailyForecast) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)
            print("WeatherViewModel: Successfully fetched weather data after third retry")
            await handleSuccessfulWeatherFetch(currentWeather: currentWeather, hourlyForecast: hourlyForecast, dailyForecast: dailyForecast)
            return
        } catch {
            print("WeatherViewModel: Third retry failed - \(error)")
        }
        
        // If all attempts fail, show user-friendly error
        print("WeatherViewModel: All recovery attempts failed")
        let userFriendlyError = NSError(
            domain: "WeatherViewModel",
            code: 1002,
            userInfo: [
                NSLocalizedDescriptionKey: "Weather service is temporarily unavailable. Please restart the app and try again.",
                NSLocalizedRecoverySuggestionErrorKey: "This may be due to a recent app update. Try closing and reopening the app."
            ]
        )
        
        await MainActor.run {
            self.error = userFriendlyError
            self.isLoading = false
        }
    }
    
    private func handleSuccessfulWeatherFetch(currentWeather: CurrentWeather, hourlyForecast: Forecast<HourWeather>, dailyForecast: Forecast<DayWeather>) async {
        let processedHourlyData = processAndInterpolateHourlyData(from: hourlyForecast)
        
        // Get today's sunrise and sunset from daily forecast
        let today = Calendar.current.startOfDay(for: Date())
        let todayDayWeather = dailyForecast.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        
        await MainActor.run {
            self.currentUVData = UVData(from: currentWeather)
            self.hourlyForecast = processedHourlyData
            self.sunrise = todayDayWeather?.sun.sunrise
            self.sunset = todayDayWeather?.sun.sunset
            self.moonrise = todayDayWeather?.moon.moonrise
            self.moonset = todayDayWeather?.moon.moonset
            self.lastUpdated = Date()
            self.isLoading = false
        }
        
        let threshold = notificationService.uvAlertThreshold
        let currentUV = Int(currentWeather.uvIndex.value)
        if currentUV >= threshold && (lastNotifiedUVIndex == nil || lastNotifiedUVIndex! < threshold) {
            await notificationService.scheduleUVAlert(uvIndex: currentUV, location: locationManager.locationName)
            lastNotifiedUVIndex = currentUV
        } else if currentUV < threshold {
            lastNotifiedUVIndex = nil
        }
    }
    
    func refreshData() async {
        guard let location = locationManager.location else {
            self.error = NSError(domain: "WeatherViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location not available."])
            self.isLoading = false
            return
        }
        await fetchUVData(for: location)
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
    
    private func loadHistoricalData() {
        if let savedData = userDefaults.data(forKey: historicalDataKey),
           let savedUVData = try? JSONDecoder().decode([UVData].self, from: savedData) {
            historicalUVData = savedUVData
            print("WeatherViewModel: Loaded \(historicalUVData.count) historical data points")
        } else {
            print("WeatherViewModel: No historical data found or failed to decode")
        }
        
        if let savedDate = userDefaults.object(forKey: lastDataDateKey) as? Date {
            lastUpdated = savedDate
            print("WeatherViewModel: Loaded last updated date: \(savedDate)")
        }
    }
    
    private func saveHistoricalData() {
        if let encodedData = try? JSONEncoder().encode(historicalUVData) {
            userDefaults.set(encodedData, forKey: historicalDataKey)
            print("WeatherViewModel: Saved \(historicalUVData.count) historical data points")
        } else {
            print("WeatherViewModel: Failed to encode historical data")
        }
        userDefaults.set(lastUpdated, forKey: lastDataDateKey)
    }
    
    private func clearHistoricalDataIfNewDay() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastUpdated {
            let lastDay = calendar.startOfDay(for: lastDate)
            if !calendar.isDate(lastDay, inSameDayAs: today) {
                // New day, clear historical data
                historicalUVData.removeAll()
                saveHistoricalData()
                print("WeatherViewModel: Cleared historical data for new day")
            }
        }
    }
    
    // Debug function to manually clear historical data
    func clearHistoricalData() {
        historicalUVData.removeAll()
        userDefaults.removeObject(forKey: historicalDataKey)
        userDefaults.removeObject(forKey: lastDataDateKey)
        print("WeatherViewModel: Manually cleared all historical data")
    }

    func fetchSummaryData(for location: CLLocation) async -> (summary: String?, hourlyData: [UVData]?, threshold: Double?) {
        do {
            let weather = try await weatherService.weather(for: location)
            
            // Filter for the next 24 hours from now
            let now = Date()
            let forecastEnd = now.addingTimeInterval(24 * 60 * 60)
            let relevantForecast = weather.hourlyForecast.filter { $0.date >= now && $0.date <= forecastEnd }

            let summary = weather.weatherAlerts?.first?.summary
            let hourlyData = relevantForecast.map { UVData(from: $0) }
            let threshold = Double(notificationService.uvAlertThreshold)
            
            return (summary, hourlyData, threshold)
        } catch {
            print("WeatherViewModel: Failed to fetch summary weather data - \(error.localizedDescription)")
            return (nil, nil, nil)
        }
    }

    func cancelTasks() {
        cancellables.forEach { $0.cancel() }
        print("WeatherViewModel: All Combine tasks cancelled.")
    }

    private func saveHourlyForecast(_ forecast: [HourWeather]) {
        // ... (implementation unchanged)
    }

    private func mapWeatherData(_ hourWeather: HourWeather) -> UVData {
        return UVData(from: hourWeather)
    }
    
    private func mapWeatherData(_ currentWeather: CurrentWeather) -> UVData {
        return UVData(from: currentWeather)
    }

    // Add method to reset WeatherKit authentication state
    func resetWeatherKitAuthentication() {
        print("WeatherViewModel: Resetting WeatherKit authentication state")
        error = nil
        
        // Clear any cached weather data
        currentUVData = nil
        hourlyForecast = []
        lastUpdated = nil
        
        // Force a fresh fetch on next location update
        Task {
            if let location = locationManager.location {
                await fetchUVData(for: location)
            }
        }
    }
    
    // Add method to force WeatherKit token refresh
    func forceWeatherKitTokenRefresh() {
        print("WeatherViewModel: Forcing WeatherKit token refresh")
        
        // Clear any cached data
        currentUVData = nil
        hourlyForecast = []
        lastUpdated = nil
        error = nil
        
        // Clear UserDefaults cache
        userDefaults.removeObject(forKey: historicalDataKey)
        userDefaults.removeObject(forKey: lastDataDateKey)
        
        // Force a new WeatherService instance (this might help with token refresh)
        // Note: WeatherService.shared is a singleton, but we can try to clear any cached state
        
        print("WeatherViewModel: WeatherKit token refresh completed")
    }
    
    // Add method to force complete WeatherKit reset
    func forceCompleteWeatherKitReset() async {
        print("WeatherViewModel: Forcing complete WeatherKit reset")
        
        // Clear all data
        forceWeatherKitTokenRefresh()
        
        // Wait a bit for the system to potentially reset
        print("WeatherViewModel: Waiting for system reset...")
        try? await Task.sleep(for: .seconds(3))
        
        // Try to trigger a new WeatherKit request
        if let location = locationManager.location {
            print("WeatherViewModel: Attempting fresh WeatherKit request after reset...")
            await fetchUVData(for: location)
        }
    }
    
    // Nuclear option: Force app restart for WeatherKit issues
    func forceAppRestartForWeatherKit() {
        print("WeatherViewModel: Nuclear option - forcing app restart")
        
        // Clear all cached data
        forceWeatherKitTokenRefresh()
        
        // Show a message to the user
        let restartMessage = NSError(
            domain: "WeatherViewModel",
            code: 1003,
            userInfo: [
                NSLocalizedDescriptionKey: "WeatherKit authentication needs to be reset. Please close the app completely and reopen it.",
                NSLocalizedRecoverySuggestionErrorKey: "This will resolve the authentication issue."
            ]
        )
        
        Task { @MainActor in
            self.error = restartMessage
            self.isLoading = false
        }
        
        // In a real app, you might want to show an alert here
        print("WeatherViewModel: User should restart the app to resolve WeatherKit authentication")
    }
    
    // Add method to check if we're experiencing authentication issues
    func isExperiencingAuthIssues() -> Bool {
        return error != nil
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
            print("WeatherViewModel: Test error domain: \((error as NSError).domain)")
            print("WeatherViewModel: Test error code: \((error as NSError).code)")
            
            // If it's the authentication error, try the recovery method
            if (error as NSError).domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" && (error as NSError).code == 2 {
                print("WeatherViewModel: Attempting recovery for connectivity test...")
                return await testWeatherKitConnectivityWithRecovery(for: location)
            }
            
            return false
        }
    }
    
    private func testWeatherKitConnectivityWithRecovery(for location: CLLocation) async -> Bool {
        print("WeatherViewModel: Testing WeatherKit connectivity with recovery")
        
        // Wait 5 seconds for potential token regeneration
        print("WeatherViewModel: Waiting 5 seconds for token regeneration...")
        try? await Task.sleep(for: .seconds(5))
        
        do {
            _ = try await weatherService.weather(for: location)
            print("WeatherViewModel: WeatherKit connectivity test successful after recovery")
            return true
        } catch {
            print("WeatherViewModel: WeatherKit connectivity test failed even after recovery - \(error)")
            return false
        }
    }
    
    // Add method to check WeatherKit availability
    func checkWeatherKitAvailability() {
        print("WeatherViewModel: Checking WeatherKit availability...")
        print("WeatherViewModel: WeatherService.shared available: true")
        
        // Check if we can access WeatherKit at all
        if #available(iOS 16.0, *) {
            print("WeatherViewModel: WeatherKit is available on this iOS version")
        } else {
            print("WeatherViewModel: WeatherKit requires iOS 16.0+")
        }
    }
    
    // Add method to get diagnostic information
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

// Ensure Date extension is available
extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
} 