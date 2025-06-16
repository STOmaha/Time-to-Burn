import Foundation
import WeatherKit
import CoreLocation

@MainActor
class WeatherViewModel: ObservableObject {
    private let weatherService = WeatherService.shared
    private let notificationService = NotificationService.shared
    
    @Published var currentUVData: UVData?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isAuthorized = false
    @Published var lastUpdateTime: Date?
    
    private var lastNotifiedUVIndex: Int?
    
    init() {
        print("WeatherViewModel: Initialized")
        Task {
            await requestAuthorizations()
        }
    }
    
    private func requestAuthorizations() async {
        print("WeatherViewModel: Requesting authorizations")
        do {
            try await notificationService.requestAuthorization()
            isAuthorized = true
            print("WeatherViewModel: Notifications authorized")
        } catch {
            self.error = error
            isAuthorized = false
            print("WeatherViewModel: Notification authorization failed - \(error.localizedDescription)")
        }
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
            
            lastUpdateTime = Date()
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
} 