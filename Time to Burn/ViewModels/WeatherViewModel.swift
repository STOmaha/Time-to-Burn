import Foundation
import WeatherKit
import CoreLocation
import SwiftUI
import UserNotifications
import WidgetKit

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let locationManager: LocationManager
    private let notificationManager = NotificationManager.shared
    private let userDefaults = UserDefaults.standard
    
    // Published properties for UI updates
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastUpdated: Date?
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    // UV Data
    @Published var currentUVData: UVData?
    @Published var hourlyUVData: [UVData] = []
    
    // Data flow state
    @Published var dataFlowState: DataFlowState = .initializing
    
    // UV threshold monitoring
    private var lastUVThresholdAlert: Int = 0
    
    // Background refresh timer
    private var backgroundRefreshTimer: Timer?
    
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
        
        print("🌤️ [WeatherViewModel] 🚀 Initializing...")
        
        // Setup daily weather refresh notification listener
        setupDailyWeatherRefreshListener()
        
        // Only initialize once
        Task {
            await requestAuthorizations()
            await initializeDataFlow()
        }
    }
    
    // MARK: - Public Methods
    
    /// Main entry point for data refresh - follows proper sequential flow
    func refreshData() async {
        print("🌤️ [WeatherViewModel] 🔄 Starting data refresh sequence")
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
    
    func appDidEnterBackground() {
        // Keep background refresh running for Live Activity updates
    }
    
    // MARK: - Private Methods - Sequential Data Flow
    
    private func initializeDataFlow() async {
        print("🌤️ [WeatherViewModel] 🔄 Step 1: Initializing data flow")
        dataFlowState = .initializing
        
        // Step 1: Check if we have location permission
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("🌤️ [WeatherViewModel] 📍 Step 2: No location permission, requesting...")
            dataFlowState = .waitingForLocation
            locationManager.requestLocation()
            return
        }
        
        // Step 2: Check if we have location data
        guard let location = locationManager.location else {
            print("🌤️ [WeatherViewModel] 📍 Step 2: No location data, waiting...")
            dataFlowState = .waitingForLocation
            locationManager.requestLocation()
            return
        }
        
        // Step 3: We have location, fetch weather data
        print("🌤️ [WeatherViewModel] ✅ Step 3: Location available, fetching weather...")
        dataFlowState = .locationReceived
        await fetchUVData(for: location)
    }
    
    private func requestAuthorizations() async {
        // Request notification permissions
        let notificationGranted = await notificationManager.requestNotificationPermission()
        print("🌤️ [WeatherViewModel] 🔔 Notifications: \(notificationGranted ? "✅ Authorized" : "❌ Denied")")
        
        // Setup notification categories
        notificationManager.setupNotificationCategories()
        
        // Schedule daily weather refresh if notifications are authorized
        if notificationGranted {
            scheduleDailyWeatherRefresh()
        }
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
        print("🌤️ [WeatherViewModel] 🌤️ Step 4: Fetching UV data for location...")
        dataFlowState = .fetchingWeather
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let (currentWeather, hourlyForecast, _) = try await weatherService.weather(for: location, including: .current, .hourly, .daily)
            
            let processedHourlyData = processHourlyData(from: hourlyForecast)
            
            await MainActor.run {
                let newUVData = UVData(from: currentWeather)
                
                self.currentUVData = newUVData
                self.hourlyUVData = processedHourlyData
                self.lastUpdated = Date()
                self.isLoading = false
                self.dataFlowState = .weatherLoaded
                
                // Beautiful console logging
                let uvEmoji = getUVEmoji(newUVData.uvIndex)
                print("🌤️ [WeatherViewModel] ✅ Step 5: Weather data loaded successfully!")
                print("   📊 Current UV: \(uvEmoji) \(newUVData.uvIndex)")
                print("   📅 Hourly Data Points: \(processedHourlyData.count)")
                print("   🕐 Updated: \(formatTime(Date()))")
                print("   📍 Location: \(locationManager.locationName)")
                print("   ──────────────────────────────────────")
                
                // Check for UV threshold alerts
                self.checkUVThresholdAlert()
                
                // Start background refresh timer after successful load
                self.startBackgroundRefresh()
                
                // Save weather data to shared storage for widget
                self.saveWeatherDataToSharedStorage()
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                self.dataFlowState = .error(error.localizedDescription)
                self.errorMessage = "WeatherKit Error: \(error.localizedDescription)\nDomain: \((error as NSError).domain)\nCode: \((error as NSError).code)"
                self.showErrorAlert = true
                
                print("🌤️ [WeatherViewModel] ❌ Step 5: Weather data fetch failed!")
                print("   💥 Error: \(error.localizedDescription)")
                print("   🔍 Domain: \((error as NSError).domain)")
                print("   🔢 Code: \((error as NSError).code)")
                print("   ──────────────────────────────────────")
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
        }
        
        // Trigger smart notification assessment
        notificationManager.triggerSmartNotificationAssessment(baseUVIndex: currentUV)
            let uvEmoji = getUVEmoji(currentUV)
            print("🌤️ [WeatherViewModel] 🔔 UV Threshold Alert:")
            print("   📊 UV Index: \(uvEmoji) \(currentUV) (Threshold: \(threshold))")
            print("   📱 Alert scheduled")
            print("   ──────────────────────────────────────")
        }
        
        // Reset alert tracking if UV drops below threshold
        if currentUV < threshold {
            lastUVThresholdAlert = 0
        }
    }
    
    // Add method to test WeatherKit connectivity
    func testWeatherKitConnectivity() async -> Bool {
        guard let location = locationManager.location else {
            print("🌤️ [WeatherViewModel] 📍 No location available for connectivity test")
            return false
        }
        
        do {
            // Try a simple weather request
            _ = try await weatherService.weather(for: location)
            return true
        } catch {
            print("🌤️ [WeatherViewModel] ❌ WeatherKit connectivity test failed:")
            print("   💥 Error: \(error)")
            print("   🔍 Domain: \((error as NSError).domain)")
            print("   🔢 Code: \((error as NSError).code)")
            print("   ──────────────────────────────────────")
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
            "uvThreshold": notificationManager.notificationSettings.uvThreshold,
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
    private func setupDailyWeatherRefreshListener() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("dailyWeatherRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🌤️ [WeatherViewModel] 🌤️ Daily weather refresh notification received")
            Task {
                await self?.refreshData()
            }
        }
    }
    
    func scheduleDailyWeatherRefresh() {
        print("🌤️ [WeatherViewModel] ⏰ Scheduling daily 8am weather refresh...")
        notificationManager.scheduleDailyWeatherRefresh()
    }
    
    func cancelDailyWeatherRefresh() {
        print("🌤️ [WeatherViewModel] ⏰ Cancelling daily weather refresh...")
        notificationManager.cancelDailyWeatherRefresh()
    }
    
    func isDailyWeatherRefreshScheduled() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        return requests.contains { $0.identifier == "daily_weather_refresh" }
    }
    
    // MARK: - Testing Methods
    func testDailyWeatherRefresh() {
        print("🌤️ [WeatherViewModel] 🧪 Testing daily weather refresh...")
        // Simulate the daily weather refresh notification
        NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
    }
    
    // MARK: - Background Refresh
    private func startBackgroundRefresh() {
        print("🌤️ [WeatherViewModel] ⏰ Starting background refresh timer")
        
        // Stop existing timer if running
        stopBackgroundRefresh()
        
        // Create timer that fires every 30 minutes (1800 seconds) for better UV monitoring
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            print("🌤️ [WeatherViewModel] ⏰ Background refresh timer fired (30-minute interval)")
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
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: Notification.Name("dailyWeatherRefresh"), object: nil)
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
    
    // MARK: - Shared Data Write for Widget
    private func saveWeatherDataToSharedStorage() {
        // Prepare shared data
        guard let currentUVData = self.currentUVData else { return }
        let sharedData = SharedUVData(
            currentUVIndex: currentUVData.uvIndex,
            timeToBurn: 0, // You may want to calculate this or pass from TimerViewModel
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
            if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
                userDefaults.set(encoded, forKey: "sharedUVData")
                userDefaults.synchronize()
                print("🌤️ [WeatherViewModel] ✅ Saved weather data to shared storage for widget")
            }
        }
        // Request widget reload
        WidgetCenter.shared.reloadAllTimelines()
    }
} 