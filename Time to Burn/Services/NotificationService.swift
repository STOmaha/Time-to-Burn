import Foundation
import UserNotifications
import BackgroundTasks
import WeatherKit

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var isHighUVAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHighUVAlertsEnabled, forKey: highUVAlertsKey)
        }
    }
    @Published var isDailyUpdatesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDailyUpdatesEnabled, forKey: dailyUpdatesKey)
        }
    }
    @Published var isLocationChangesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLocationChangesEnabled, forKey: locationChangesKey)
        }
    }
    @Published var uvAlertThreshold: Int {
        didSet {
            UserDefaults.standard.set(uvAlertThreshold, forKey: uvAlertThresholdKey)
        }
    }
    
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
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions()
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
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
        print("[BGTask] handleBackgroundTask started")
        
        // Create a task expiration handler
        task.expirationHandler = {
            print("[BGTask] Expired before completion")
            task.setTaskCompleted(success: false)
        }
        
        // Check if we're within active hours (8 AM - 8 PM)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        guard hour >= 8 && hour < 20 else {
            print("[BGTask] Outside active hours (8 AM - 8 PM), skipping update")
            task.setTaskCompleted(success: true)
            scheduleBackgroundTask() // Schedule next check
            return
        }
        
        // Perform the UV check
        Task {
            do {
                if let location = LocationManager().location {
                    print("[BGTask] Got location: \(location)")
                    let weather = try await weatherService.weather(for: location)
                    let uvIndex = Int(weather.currentWeather.uvIndex.value)
                    print("[BGTask] Fetched UV Index: \(uvIndex)")
                    
                    if uvIndex >= uvAlertThreshold && uvIndex > lastNotifiedUVIndex && self.isHighUVAlertsEnabled {
                        print("[BGTask] Scheduling High UV Alert for index \(uvIndex)")
                        await self.scheduleUVAlert(uvIndex: uvIndex, location: LocationManager().locationName)
                        lastNotifiedUVIndex = uvIndex
                    } else if uvIndex < uvAlertThreshold {
                        print("[BGTask] UV Index below threshold, resetting lastNotifiedUVIndex")
                        lastNotifiedUVIndex = 0
                    } else {
                        print("[BGTask] No notification needed (already notified or below threshold)")
                    }
                } else {
                    print("[BGTask] No location available")
                }
                task.setTaskCompleted(success: true)
                print("[BGTask] Task completed successfully")
            } catch {
                print("[BGTask] Background task failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
            
            // Schedule the next background task
            scheduleBackgroundTask()
        }
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        // Set the earliest begin date to the next 15-minute interval
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let minutesUntilNext15 = 15 - (minute % 15)
        request.earliestBeginDate = calendar.date(byAdding: .minute, value: minutesUntilNext15, to: now)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Successfully scheduled background task for next 15-minute interval")
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
    
    // Add a public test function to trigger a High UV notification manually
    func testHighUVNotification() {
        print("[Test] Triggering manual High UV notification...")
        Task {
            await self.scheduleUVAlert(uvIndex: uvAlertThreshold, location: "Test Location")
        }
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from Time to Burn"
        content.sound = .default
        
        // Create a trigger that fires immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: trigger
        )
        
        // Add the request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error.localizedDescription)")
            } else {
                print("Test notification sent successfully")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
} 
