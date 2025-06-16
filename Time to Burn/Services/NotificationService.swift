import Foundation
import UserNotifications
import BackgroundTasks
import WeatherKit

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var isHighUVAlertsEnabled: Bool
    @Published var isDailyUpdatesEnabled: Bool
    @Published var isLocationChangesEnabled: Bool
    @Published var uvAlertThreshold: Int
    
    private let highUVAlertsKey = "highUVAlertsEnabled"
    private let dailyUpdatesKey = "dailyUpdatesEnabled"
    private let locationChangesKey = "locationChangesEnabled"
    private let uvAlertThresholdKey = "uvAlertThreshold"
    private let backgroundTaskIdentifier = "com.timetoburn.uvcheck"
    private let weatherService = WeatherService.shared
    private let lastNotifiedUVKey = "lastNotifiedUVIndex"
    private var lastNotifiedUVIndex: Int {
        get { UserDefaults.standard.integer(forKey: lastNotifiedUVKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastNotifiedUVKey) }
    }
    
    override init() {
        self.isHighUVAlertsEnabled = UserDefaults.standard.bool(forKey: highUVAlertsKey)
        self.isDailyUpdatesEnabled = UserDefaults.standard.bool(forKey: dailyUpdatesKey)
        self.isLocationChangesEnabled = UserDefaults.standard.bool(forKey: locationChangesKey)
        let threshold = UserDefaults.standard.integer(forKey: uvAlertThresholdKey)
        self.uvAlertThreshold = threshold == 0 ? 6 : threshold
        super.init()
        requestNotificationPermissions()
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: .main) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        // Schedule the first background task
        scheduleBackgroundTask()
    }
    
    func handleBackgroundTask(task: BGAppRefreshTask) {
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
                    
                    if uvIndex > uvAlertThreshold && uvIndex > lastNotifiedUVIndex && self.isHighUVAlertsEnabled {
                        await self.scheduleUVAlert(uvIndex: uvIndex, location: LocationManager().locationName)
                        lastNotifiedUVIndex = uvIndex
                    } else if uvIndex <= uvAlertThreshold {
                        lastNotifiedUVIndex = 0
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
            print("Successfully scheduled background task")
        } catch {
            print("Could not schedule background task: \(error.localizedDescription)")
        }
    }
    
    func scheduleUVAlert(uvIndex: Int, location: String) async {
        guard isHighUVAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "High UV Alert"
        content.body = "UV Index is \(uvIndex) in \(location). Take precautions!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "UV_ALERT"
        
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
    
    func updateNotificationPreferences(highUVAlerts: Bool, dailyUpdates: Bool, locationChanges: Bool, uvAlertThreshold: Int? = nil) {
        isHighUVAlertsEnabled = highUVAlerts
        isDailyUpdatesEnabled = dailyUpdates
        isLocationChangesEnabled = locationChanges
        if let threshold = uvAlertThreshold {
            self.uvAlertThreshold = threshold
        }
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
