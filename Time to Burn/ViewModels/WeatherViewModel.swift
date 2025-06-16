import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let notificationService: NotificationService
    
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
        Task {
            await requestAuthorizations()
        }
    }
    
    private func requestAuthorizations() async {
        print("WeatherViewModel: Requesting authorizations")
        notificationService.requestNotificationPermissions()
        isAuthorized = true
        print("WeatherViewModel: Notifications permission requested")
    }
    
    func fetchUVData(for location: CLLocation) async {
        print("WeatherViewModel: Fetching UV data for location - \(location.coordinate)")
        isLoading = true
        error = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            print("WeatherViewModel: Successfully fetched weather data")
            
            let uvIndex = Int(weather.currentWeather.uvIndex.value)
            print("WeatherViewModel: UV Index - \(uvIndex)")
            
            let timeToBurn = UVData.calculateTimeToBurn(uvIndex: uvIndex)
            let advice = UVData.getAdvice(uvIndex: uvIndex)
            
            currentUVData = UVData(
                uvIndex: uvIndex,
                timeToBurn: timeToBurn,
                location: "", // Will be set by LocationManager
                timestamp: Date(),
                advice: advice
            )
            
            lastUpdated = Date()
            print("WeatherViewModel: Created UV data object")
            
            // Check if we should send a notification
            let threshold = notificationService.uvAlertThreshold
            if uvIndex >= threshold && (lastNotifiedUVIndex == nil || lastNotifiedUVIndex! < threshold) {
                await notificationService.scheduleUVAlert(uvIndex: uvIndex, location: "")
                lastNotifiedUVIndex = uvIndex
                print("WeatherViewModel: Scheduled UV alert for index \(uvIndex)")
            } else if uvIndex < threshold {
                lastNotifiedUVIndex = nil
            }
            
        } catch {
            self.error = error
            currentUVData = nil
            print("WeatherViewModel: Failed to fetch weather data - \(error.localizedDescription)")
        }
        
        isLoading = false
        print("WeatherViewModel: Finished loading UV data")
    }
    
    func refreshData() async {
        print("WeatherViewModel: Refreshing data")
        if let location = LocationManager().location {
            await fetchUVData(for: location)
        } else {
            print("WeatherViewModel: No location available for refresh")
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