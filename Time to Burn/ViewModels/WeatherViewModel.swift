import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
// import UserNotifications
import WidgetKit

// MARK: - Connection Status
enum ConnectionStatus {
    case connected
    case reconnecting
    case offline
    
    var displayText: String {
        switch self {
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting..."
        case .offline: return "Offline"
        }
    }
    
    var emoji: String {
        switch self {
        case .connected: return "🌐"
        case .reconnecting: return "🔄"
        case .offline: return "📡"
        }
    }
}

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager
    // private let notificationManager = NotificationManager.shared
    private let userDefaults = UserDefaults.standard
    
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastUpdated: Date?
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    // Retry logic properties
    private var retryCount = 0
    private let maxRetries = 3
    private var isRetrying = false
    @Published var connectionStatus: ConnectionStatus = .connected
    
    // UV Data
    @Published var currentUVData: UVData?
    @Published var hourlyUVData: [UVData] = []
    
    // Additional Weather Data for Misery Index
    @Published var currentTemperature: Double?
    @Published var currentHumidity: Double?
    @Published var currentWindSpeed: Double?
    
    // Data flow state
    @Published var dataFlowState: DataFlowState = .initializing
    
    // UV threshold monitoring
    // private var lastUVThresholdAlert: Int = 0
    
    // Background refresh timer
    private var backgroundRefreshTimer: Timer?

    // Debouncing to prevent cascade loops
    private var lastRefreshTime: Date?
    private var isRefreshing = false
    private let minRefreshInterval: TimeInterval = 5 // Minimum 5 seconds between refreshes

    // Background refresh interval with jitter (to prevent thundering herd at scale)
    private let baseRefreshInterval: TimeInterval = 1800 // 30 minutes base interval
    private let jitterOffsetKey = "weather_jitter_offset"

    /// Stable per-user jitter offset (0-300 seconds) persisted across app restarts
    /// This spreads WeatherKit API requests across a 5-minute window to avoid rate limiting
    private var userJitterOffset: TimeInterval {
        if let stored = userDefaults.object(forKey: jitterOffsetKey) as? Double, stored > 0 {
            return stored
        }
        // Generate stable random offset (0-300 seconds = 0-5 minutes)
        let offset = Double.random(in: 0...300)
        userDefaults.set(offset, forKey: jitterOffsetKey)
        return offset
    }

    // Weekly forecast caching - only fetch 7-day forecast once per day
    private let weeklyForecastDateKey = "lastWeeklyForecastDate"
    private let weeklyForecastCacheKey = "weeklyForecastCache"

    enum DataFlowState: Equatable {
        case initializing
        case waitingForLocation
        case locationReceived
        case fetchingWeather
        case weatherLoaded
        case error(String)
        
        var description: String {
            switch self {
            case .initializing: return "🚀 Initializing..."
            case .waitingForLocation: return "📍 Waiting for location..."
            case .locationReceived: return "✅ Location received"
            case .fetchingWeather: return "🌤️ Fetching weather data..."
            case .weatherLoaded: return "✅ Weather data loaded"
            case .error(let message): return "❌ Error: \(message)"
            }
        }
        
        static func == (lhs: DataFlowState, rhs: DataFlowState) -> Bool {
            switch (lhs, rhs) {
            case (.initializing, .initializing),
                 (.waitingForLocation, .waitingForLocation),
                 (.locationReceived, .locationReceived),
                 (.fetchingWeather, .fetchingWeather),
                 (.weatherLoaded, .weatherLoaded):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        logInfo(.weather, "WeatherViewModel initializing")
        
        // Setup daily weather refresh notification listener
        // setupDailyWeatherRefreshListener()
        
        // Only initialize once
        Task {
            // await requestAuthorizations()
            await initializeDataFlow()
        }
    }
    
    // MARK: - Public Methods
    
    /// Main entry point for data refresh - follows proper sequential flow with debouncing
    func refreshData() async {
        // Debounce: prevent cascade loops and redundant refreshes
        if isRefreshing {
            logInfo(.weather, "Refresh already in progress, skipping")
            return
        }

        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < minRefreshInterval {
            logInfo(.weather, "Refresh throttled (last refresh \(Int(Date().timeIntervalSince(lastRefresh)))s ago)")
            return
        }

        isRefreshing = true
        lastRefreshTime = Date()

        defer {
            Task { @MainActor in
                self.isRefreshing = false
            }
        }

        logInfo(.weather, "Starting data refresh sequence")

        // Reset retry state for fresh start
        resetRetryState()

        // Use existing location instead of forcing refresh to prevent cascade loops
        // The location should already be updated by LocationManager
        await initializeDataFlow()
    }
    
    func appBecameActive() {
        // Refresh data when app becomes active
        Task {
            await refreshData()
        }
    }
    
    func appWillResignActive() {
        // Keep background refresh running
    }
    
    // MARK: - Retry Logic
    private func shouldRetryError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for network-related errors that are worth retrying
        if nsError.domain == "WeatherDaemon.WDSClient-Errors" && nsError.code == 0 {
            return true // Network timeout
        }
        
        // Check for common network error codes
        if nsError.code == NSURLErrorTimedOut ||
           nsError.code == NSURLErrorCannotConnectToHost ||
           nsError.code == NSURLErrorNetworkConnectionLost ||
           nsError.code == NSURLErrorNotConnectedToInternet {
            return true
        }
        
        return false
    }
    
    private func getRetryDelay() -> TimeInterval {
        // Exponential backoff: 2^retryCount seconds (2, 4, 8 seconds)
        let baseDelay: TimeInterval = 2.0
        return baseDelay * pow(2.0, Double(retryCount))
    }
    
    private func resetRetryState() {
        retryCount = 0
        isRetrying = false
        connectionStatus = .connected
    }
    
    private func handleRetryableError(_ error: Error, location: CLLocation) async {
        guard retryCount < maxRetries && !isRetrying else {
            // Max retries reached, set offline status but don't show alert
            await MainActor.run {
                self.connectionStatus = .offline
                self.isLoading = false
                self.dataFlowState = .error("Network temporarily unavailable")
            }
            
            logWarning(.weather, "Max retries reached, going offline", data: [
                "Retry Count": "\(retryCount)",
                "Error": error.localizedDescription
            ])
            return
        }
        
        isRetrying = true
        retryCount += 1
        
        await MainActor.run {
            self.connectionStatus = .reconnecting
        }
        
        let retryDelay = getRetryDelay()
        
        logInfo(.weather, "Retrying WeatherKit request", data: [
            "Attempt": "\(retryCount)/\(maxRetries)",
            "Delay": "\(Int(retryDelay))s",
            "Error": error.localizedDescription
        ])
        
        // Wait before retrying
        try? await Task.sleep(for: .seconds(retryDelay))
        
        // Retry the request
        await fetchUVData(for: location)
    }
    
    func appDidEnterBackground() {
        // Keep background refresh running for Live Activity updates
    }
    
    // MARK: - Private Methods - Sequential Data Flow
    
    private func initializeDataFlow() async {
        dataFlowState = .initializing
        
        let locationStatus = locationManager.authorizationStatus
        let hasLocation = locationManager.location != nil
        
        logInfo(.weather, "Initializing data flow", data: [
            "Permission": locationStatus.displayName,
            "Has Location": hasLocation ? "✅" : "❌"
        ])
        
        // Step 1: Check if we have location permission
        guard locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways else {
            dataFlowState = .waitingForLocation
            logWarning(.location, "Location permission required", data: [
                "Current Status": locationStatus.displayName
            ])
            locationManager.requestLocation()
            return
        }
        
        // Step 2: Check if we have location data and wait for it if needed
        guard let location = locationManager.location else {
            dataFlowState = .waitingForLocation
            logInfo(.location, "Waiting for location data")
            // Request location (don't force refresh to prevent cascade)
            locationManager.requestLocation()

            // Wait for location update with timeout
            for i in 0..<10 { // Wait up to 10 seconds
                if let newLocation = locationManager.location {
                    log.logLocation(newLocation, name: locationManager.locationName, context: "Fresh location acquired")
                    dataFlowState = .locationReceived
                    await fetchUVData(for: newLocation)
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second

                if i == 4 { // Log at halfway point
                    logInfo(.location, "Still waiting for location", data: ["Wait Time": "5 seconds"])
                }
            }

            // If still no location, log error
            logError(.location, "Location timeout after 10 seconds")
            dataFlowState = .error("Location unavailable")
            return
        }
        
        // Step 3: We have location, fetch weather data
        log.logLocation(location, name: locationManager.locationName, context: "Using existing location")
        dataFlowState = .locationReceived
        await fetchUVData(for: location)
    }
    
    // private func requestAuthorizations() async {
    //     // Request notification permissions
    //     let notificationGranted = await notificationManager.requestNotificationPermission()
    //     print("🌤️ [WeatherViewModel] 🔔 Notifications: \(notificationGranted ? "✅ Authorized" : "❌ Denied")")
    //     
    //     // Setup notification categories
    //     notificationManager.setupNotificationCategories()
    //     
    //     // Schedule daily weather refresh if notifications are authorized
    //     if notificationGranted {
    //         scheduleDailyWeatherRefresh()
    //     }
    // }
    
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

    // MARK: - Weekly Forecast Caching

    /// Check if we need to refresh the 7-day forecast (only once per day)
    private func needsWeeklyForecastRefresh() -> Bool {
        guard let lastFetchDate = UserDefaults.standard.object(forKey: weeklyForecastDateKey) as? Date else {
            return true // Never fetched
        }
        return !Calendar.current.isDateInToday(lastFetchDate)
    }

    /// Save the weekly forecast to UserDefaults cache
    private func saveWeeklyForecastCache(_ data: [UVData]) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: weeklyForecastCacheKey)
            UserDefaults.standard.set(Date(), forKey: weeklyForecastDateKey)
        }
    }

    /// Load cached weekly forecast from UserDefaults
    private func loadWeeklyForecastCache() -> [UVData]? {
        guard let data = UserDefaults.standard.data(forKey: weeklyForecastCacheKey),
              let decoded = try? JSONDecoder().decode([UVData].self, from: data) else {
            return nil
        }
        return decoded
    }

    /// Process full 7-day forecast (called once per day)
    private func processFullWeekForecast(from forecast: Forecast<HourWeather>) -> [UVData] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? Date()

        return forecast
            .filter { $0.date >= startOfToday && $0.date < endOfWeek }
            .map { UVData(from: $0) }
    }

    /// Process today's hourly data only (for intra-day refreshes)
    private func processTodayHourlyData(from forecast: Forecast<HourWeather>) -> [UVData] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()

        return forecast
            .filter { $0.date >= startOfToday && $0.date < endOfToday }
            .map { UVData(from: $0) }
    }

    /// Merge today's fresh data with cached future days
    private func mergeTodayWithCachedForecast(todayData: [UVData], cachedData: [UVData]) -> [UVData] {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()

        // Keep future days from cache (tomorrow onwards)
        let futureDays = cachedData.filter { $0.date >= startOfTomorrow }

        // Combine today's fresh data with cached future days
        return todayData + futureDays
    }
    
    func fetchUVData(for location: CLLocation) async {
        dataFlowState = .fetchingWeather

        // Check if we need a full 7-day refresh or just today's data
        let needsFullWeekRefresh = needsWeeklyForecastRefresh()
        logInfo(.weather, needsFullWeekRefresh ? "Fetching full 7-day forecast" : "Refreshing today's UV data only")

        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            let (currentWeather, hourlyForecast, _) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)

            // Process hourly data based on whether we need full week or just today
            let processedHourlyData: [UVData]
            if needsFullWeekRefresh {
                // First fetch of the day: get full 7-day forecast and cache it
                processedHourlyData = processFullWeekForecast(from: hourlyForecast)
                saveWeeklyForecastCache(processedHourlyData)
            } else {
                // Subsequent fetches: only refresh today, merge with cached future days
                let todayData = processTodayHourlyData(from: hourlyForecast)
                if let cachedData = loadWeeklyForecastCache() {
                    processedHourlyData = mergeTodayWithCachedForecast(todayData: todayData, cachedData: cachedData)
                } else {
                    // Fallback: if cache is missing, do a full refresh
                    processedHourlyData = processFullWeekForecast(from: hourlyForecast)
                    saveWeeklyForecastCache(processedHourlyData)
                }
            }

            await MainActor.run {
                let newUVData = UVData(from: currentWeather)

                self.currentUVData = newUVData
                self.hourlyUVData = processedHourlyData

                // Store additional weather data for misery index
                self.currentTemperature = currentWeather.temperature.value
                self.currentHumidity = currentWeather.humidity
                self.currentWindSpeed = currentWeather.wind.speed.value * 3.6 // Convert m/s to km/h

                self.lastUpdated = Date()
                self.isLoading = false
                self.dataFlowState = .weatherLoaded

                // Reset retry state on successful fetch
                self.resetRetryState()

                // Log comprehensive weather data
                log.logUVData(newUVData, location: locationManager.locationName)

                logSuccess(.weather, "Weather data loaded successfully", data: [
                    "Hourly Data Points": "\(processedHourlyData.count)",
                    "Fetch Type": needsFullWeekRefresh ? "Full 7-day" : "Today only + cached",
                    "Next Update": "30 minutes"
                ])

                // Start background refresh timer after successful load
                self.startBackgroundRefresh()

                // Save weather data to shared storage for widget
                self.saveWeatherDataToSharedStorage()

                // Sync UV data to Supabase for backend monitoring
                Task {
                    await self.syncUVDataToSupabase(location: location, uvData: newUVData)
                }
            }
            
        } catch {
            // Check if this is a retryable error
            if shouldRetryError(error) {
                await handleRetryableError(error, location: location)
            } else {
                // Non-retryable error - handle gracefully without showing alert
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                    self.dataFlowState = .error("Weather data temporarily unavailable")
                    self.connectionStatus = .offline
                    // Removed: self.showErrorAlert = true - NO MORE USER ALERTS!
                }
                
                logError(.weather, "WeatherKit API failed (non-retryable)", data: [
                    "Error": error.localizedDescription,
                    "Domain": (error as NSError).domain,
                    "Code": "\((error as NSError).code)",
                    "Location": locationManager.locationName,
                    "Action": "Silent failure - no user alert"
                ])
            }
        }
    }
    
    // MARK: - UV Threshold Monitoring
    // private func checkUVThresholdAlert() {
    //     guard let currentUV = currentUVData?.uvIndex else { return }
    //     
    //     let threshold = notificationManager.notificationSettings.uvThreshold
    //     
    //     // Only send alert if UV is above threshold and we haven't already alerted for this UV level
    //     if currentUV >= threshold && lastUVThresholdAlert != currentUV {
    //         notificationManager.scheduleUVThresholdAlert(uvIndex: currentUV, threshold: threshold)
    //         lastUVThresholdAlert = currentUV
    //     }
    //     
    //     // Trigger smart notification assessment
    //     notificationManager.triggerSmartNotificationAssessment(baseUVIndex: currentUV)
    //     
    //     // Log the alert if it was scheduled
    //     if currentUV >= threshold && lastUVThresholdAlert == currentUV {
    //         let uvEmoji = getUVEmoji(currentUV)
    //         print("🌤️ [WeatherViewModel] 🔔 UV Threshold Alert:")
    //         print("   📊 UV Index: \(uvEmoji) \(currentUV) (Threshold: \(threshold))")
    //         print("   📱 Alert scheduled")
    //         print("   ──────────────────────────────────────")
    //     }
    //     
    //     // Reset alert tracking if UV drops below threshold
    //     if currentUV < threshold {
    //         lastUVThresholdAlert = 0
    //     }
    // }
    
    // Add method to test WeatherKit connectivity
    func testWeatherKitConnectivity() async -> Bool {
        guard let location = locationManager.location else {
            logWarning(.weather, "No location available for connectivity test")
            return false
        }
        
        do {
            // Try a simple weather request
            _ = try await weatherService.weather(for: location)
            logSuccess(.weather, "WeatherKit connectivity test passed")
            return true
        } catch {
            logError(.weather, "WeatherKit connectivity test failed", data: [
                "Error": error.localizedDescription,
                "Domain": (error as NSError).domain,
                "Code": "\((error as NSError).code)"
            ])
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
            // "notificationsAuthorized": notificationManager.isAuthorized,
            "currentUVIndex": currentUVData?.uvIndex ?? 0,
            // "uvThreshold": notificationManager.notificationSettings.uvThreshold,
            "dataFlowState": dataFlowState.description
        ]
    }
    
    // MARK: - UV Data Access
    func getCurrentUVIndex() -> Int {
        return currentUVData?.uvIndex ?? 0
    }
    
    func getCurrentUVData() -> UVData? {
        return currentUVData
    }
    
    // MARK: - Daily Weather Refresh
    // private func setupDailyWeatherRefreshListener() {
    //     NotificationCenter.default.addObserver(
    //         forName: Notification.Name("dailyWeatherRefresh"),
    //         object: nil,
    //         queue: .main
    //     ) { [weak self] _ in
    //         print("🌤️ [WeatherViewModel] 🔔 Daily weather refresh notification received")
    //         Task {
    //             await self?.refreshData()
    //         }
    //     }
    //     
    //     // Add listener for weather update notifications from push notifications
    //     NotificationCenter.default.addObserver(
    //         forName: Notification.Name("refreshWeatherData"),
    //         object: nil,
    //         queue: .main
    //     ) { [weak self] _ in
    //         print("🌤️ [WeatherViewModel] 🔔 Weather update notification received")
    //         Task {
    //             await self?.refreshData()
    //         }
    //     }
    // }
    
    // func scheduleDailyWeatherRefresh() {
    //     print("🌤️ [WeatherViewModel] ⏰ Scheduling daily 8am weather refresh...")
    //     notificationManager.scheduleDailyWeatherRefresh()
    // }
    // 
    // func cancelDailyWeatherRefresh() {
    //     print("🌤️ [WeatherViewModel] ⏰ Cancelling daily weather refresh...")
    //     notificationManager.cancelDailyWeatherRefresh()
    // }
    // 
    // func isDailyWeatherRefreshScheduled() async -> Bool {
    //     let center = UNUserNotificationCenter.current()
    //     let requests = await center.pendingNotificationRequests()
    //     return requests.contains { $0.identifier == "daily_weather_refresh" }
    // }
    // 
    // // MARK: - Testing Methods
    // func testDailyWeatherRefresh() {
    //     print("🌤️ [WeatherViewModel] 🧪 Testing daily weather refresh...")
    //     // Simulate the daily weather refresh notification
    //     NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
    // }
    
    // MARK: - Background Refresh
    private func startBackgroundRefresh() {
        // Stop existing timer if running
        stopBackgroundRefresh()

        // Calculate jittered interval to spread requests across users
        // This prevents "thundering herd" when many users refresh simultaneously
        let jitteredInterval = baseRefreshInterval + userJitterOffset

        logInfo(.weather, "Starting background refresh timer", data: [
            "Base Interval": "30 minutes",
            "Jitter Offset": "\(Int(userJitterOffset)) seconds",
            "Effective Interval": "\(String(format: "%.1f", jitteredInterval / 60)) minutes",
            "Auto Refresh": "Enabled"
        ])

        // Create timer with jittered interval for better UV monitoring at scale
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: jitteredInterval, repeats: true) { [weak self] _ in
            logInfo(.weather, "Background refresh triggered")
            Task {
                await self?.refreshData()
            }
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
        
        // Remove notification observers
        // NotificationCenter.default.removeObserver(self, name: Notification.Name("dailyWeatherRefresh"), object: nil)
        // NotificationCenter.default.removeObserver(self, name: Notification.Name("refreshWeatherData"), object: nil)
    }
    
    // MARK: - Helper Methods for Beautiful Logging
    
    private func getUVEmoji(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0: return "🌙"
        case 1...2: return "🌤️"
        case 3...5: return "☀️"
        case 6...7: return "🔥"
        case 8...10: return "☠️"
        default: return "💀"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
    
    // MARK: - Supabase Sync
    
    /// Sync UV data to Supabase for backend monitoring
    private func syncUVDataToSupabase(location: CLLocation, uvData: UVData) async {
        // Only sync if user is authenticated
        guard SupabaseService.shared.isAuthenticated else {
            logInfo(.data, "Skipping Supabase sync - user not authenticated")
            return
        }
        
        logInfo(.data, "Syncing UV data to Supabase")
        
        // Fetch environmental factors
        let environmentalDataService = EnvironmentalDataService.shared
        guard let environmentalFactors = await environmentalDataService.fetchEnvironmentalData(for: location) else {
            logWarning(.data, "Failed to fetch environmental factors for Supabase sync")
            return
        }
        
        // Calculate adjusted UV with environmental factors
        let adjustedUV = calculateAdjustedUV(baseUV: uvData.uvIndex, factors: environmentalFactors)
        
        // Get user's UV threshold from settings (default: 6)
        let uvThreshold = UserDefaults.standard.integer(forKey: "uvAlertThreshold")
        let threshold = uvThreshold == 0 ? 6 : uvThreshold
        
        // Use BackgroundSyncService for smart syncing
        await BackgroundSyncService.shared.syncUVData(
            location: location,
            locationName: locationManager.locationName,
            currentUV: uvData.uvIndex,
            adjustedUV: adjustedUV,
            environmentalFactors: environmentalFactors,
            threshold: threshold
        )
    }
    
    /// Calculate adjusted UV index with environmental factors
    private func calculateAdjustedUV(baseUV: Int, factors: EnvironmentalFactors) -> Int {
        var adjustedUV = Double(baseUV)
        
        // Altitude adjustment (10% increase per 1000m)
        let altitudeMultiplier = 1.0 + (factors.altitude / 1000.0) * 0.10
        adjustedUV *= altitudeMultiplier
        
        // Snow reflection (can add up to 80% more UV)
        let snowReflection = factors.snowConditions.snowType.reflectionFactor
        adjustedUV += Double(baseUV) * snowReflection * (factors.snowConditions.snowCoverage / 100.0)
        
        // Water reflection (can add up to 25% more UV if nearby)
        if factors.waterProximity.distanceToWater < 1000 {
            let waterReflection = factors.waterProximity.waterBodyType.reflectionFactor
            let distanceFactor = max(0.1, 1.0 - (factors.waterProximity.distanceToWater / 1000.0))
            adjustedUV += Double(baseUV) * waterReflection * distanceFactor
        }
        
        return Int(round(adjustedUV))
    }
    
    // MARK: - Shared Data Write for Widget
    private func saveWeatherDataToSharedStorage() {
        // Prepare shared data
        guard let currentUVData = self.currentUVData else { return }
        
        // Calculate time to burn based on current UV index
        let calculatedTimeToBurn = UVColorUtils.calculateTimeToBurn(uvIndex: currentUVData.uvIndex)
        
        let sharedData = SharedUVData(
            currentUVIndex: currentUVData.uvIndex,
            timeToBurn: calculatedTimeToBurn,
            elapsedTime: 0,
            totalExposureTime: 0,
            isTimerRunning: false,
            lastSunscreenApplication: nil,
            sunscreenReapplyTimeRemaining: 0,
            exposureStatus: .safe,
            exposureProgress: 0.0,
            locationName: locationManager.locationName,
            lastUpdated: self.lastUpdated ?? Date(),
            hourlyUVData: self.hourlyUVData,
            currentCloudCover: currentUVData.cloudCover,
            currentCloudCondition: currentUVData.cloudCondition
        )
        // Save to shared storage
        if let encoded = try? JSONEncoder().encode(sharedData) {
            if let userDefaults = UserDefaults(suiteName: "group.com.anvilheadstudios.timetoburn") {
                userDefaults.set(encoded, forKey: "sharedUVData")
                userDefaults.synchronize()
                logSuccess(.data, "Widget data synchronized", data: [
                    "UV Index": "\(currentUVData.uvIndex)",
                    "Time to Burn": "\(calculatedTimeToBurn/60) minutes",
                    "Cloud Cover": "\(Int(currentUVData.cloudCover * 100))%",
                    "Cloud Condition": currentUVData.cloudCondition,
                    "Location": locationManager.locationName
                ])
            }
        }
        // Request widget reload
        WidgetCenter.shared.reloadAllTimelines()
    }
}

 