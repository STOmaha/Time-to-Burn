import Foundation
import UserNotifications
import BackgroundTasks
import WeatherKit

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isHighUVAlertsEnabled = true
    @Published var isDailyUpdatesEnabled = false
    @Published var isLocationChangesEnabled = false
    
    private let highUVAlertsKey = "highUVAlertsEnabled"
    private let dailyUpdatesKey = "dailyUpdatesEnabled"
    private let locationChangesKey = "locationChangesEnabled"
    private let backgroundTaskIdentifier = "com.timetoburn.uvcheck"
    private let weatherService = WeatherService.shared
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerBackgroundTask()
        
        // Load saved preferences
        isHighUVAlertsEnabled = UserDefaults.standard.bool(forKey: highUVAlertsKey)
        isDailyUpdatesEnabled = UserDefaults.standard.bool(forKey: dailyUpdatesKey)
        isLocationChangesEnabled = UserDefaults.standard.bool(forKey: locationChangesKey)
    }
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
    }
    
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        // Schedule the next background task
        scheduleBackgroundTask()
        
        // Create a task expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform the UV check
        Task {
            do {
                if let location = LocationManager().location {
                    let weather = try await weatherService.weather(for: location)
                    let uvIndex = Int(weather.currentWeather.uvIndex.value)
                    
                    if uvIndex >= 6 && self.isHighUVAlertsEnabled {
                        await self.scheduleUVAlert(uvIndex: uvIndex, location: LocationManager().locationName)
                    }
                }
                task.setTaskCompleted(success: true)
            } catch {
                print("Background task failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // Check every 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error.localizedDescription)")
        }
    }
    
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .timeSensitive]
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        
        // Schedule the first background task after authorization
        scheduleBackgroundTask()
    }
    
    func scheduleUVAlert(uvIndex: Int, location: String) async {
        guard isHighUVAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "High UV Alert"
        content.body = "UV Index is \(uvIndex) in \(location). Take precautions!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        // Create a unique identifier for this notification
        let identifier = "uv-alert-\(Date().timeIntervalSince1970)"
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled UV alert for index \(uvIndex)")
        } catch {
            print("Failed to schedule UV alert: \(error.localizedDescription)")
        }
    }
    
    func scheduleDailyUpdate(location: String, uvIndex: Int) {
        guard isDailyUpdatesEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Daily UV Update"
        content.body = "Today's UV Index in \(location) is \(uvIndex). \(getAdviceForUVIndex(uvIndex))"
        content.sound = .default
        
        // Create a date components for 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "daily-uv-update",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleLocationChangeNotification(newLocation: String, uvIndex: Int) {
        guard isLocationChangesEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "New Location Detected"
        content.body = "UV Index in \(newLocation) is \(uvIndex). \(getAdviceForUVIndex(uvIndex))"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "location-change-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func updateNotificationPreferences(highUVAlerts: Bool, dailyUpdates: Bool, locationChanges: Bool) {
        isHighUVAlertsEnabled = highUVAlerts
        isDailyUpdatesEnabled = dailyUpdates
        isLocationChangesEnabled = locationChanges
        
        // Save preferences
        UserDefaults.standard.set(highUVAlerts, forKey: highUVAlertsKey)
        UserDefaults.standard.set(dailyUpdates, forKey: dailyUpdatesKey)
        UserDefaults.standard.set(locationChanges, forKey: locationChangesKey)
        
        // Remove existing notifications if disabled
        if !highUVAlerts {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["uv-alert"])
        }
        if !dailyUpdates {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-uv-update"])
        }
    }
    
    private func getAdviceForUVIndex(_ index: Int) -> String {
        switch index {
        case 0...2: return "Low risk - no protection required."
        case 3...5: return "Moderate risk - wear sunscreen and seek shade."
        case 6...7: return "High risk - reduce time in sun, wear protection."
        case 8...10: return "Very high risk - minimize sun exposure."
        default: return "Extreme risk - avoid sun exposure."
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
} 