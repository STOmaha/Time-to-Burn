import Foundation
import UserNotifications
import BackgroundTasks
import WeatherKit
import CoreLocation

class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    @Published var isHighUVAlertsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isHighUVAlertsEnabled, forKey: highUVAlertsKey)
            if isHighUVAlertsEnabled {
                scheduleBackgroundTask()
            }
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
    private let lastNotificationDateKey = "lastNotificationDate"
    private var isBackgroundTaskRegistered = false
    
    private var lastNotifiedUVIndex: Int {
        get { UserDefaults.standard.integer(forKey: lastNotifiedUVKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastNotifiedUVKey) }
    }
    
    private var lastNotificationDate: Date? {
        get { UserDefaults.standard.object(forKey: lastNotificationDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastNotificationDateKey) }
    }
    
    override init() {
        self.isHighUVAlertsEnabled = UserDefaults.standard.bool(forKey: highUVAlertsKey)
        self.isDailyUpdatesEnabled = UserDefaults.standard.bool(forKey: dailyUpdatesKey)
        self.isLocationChangesEnabled = UserDefaults.standard.bool(forKey: locationChangesKey)
        let threshold = UserDefaults.standard.integer(forKey: uvAlertThresholdKey)
        self.uvAlertThreshold = threshold == 0 ? 6 : threshold
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
        requestNotificationPermissions()
    }
    
    private func setupNotificationCategories() {
        // Create notification categories with actions
        let viewAction = UNNotificationAction(
            identifier: "VIEW_UV_INFO",
            title: "View Details",
            options: [.foreground]
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: [.destructive]
        )
        
        let uvAlertCategory = UNNotificationCategory(
            identifier: "UV_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let dailyUpdateCategory = UNNotificationCategory(
            identifier: "DAILY_UPDATE",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([uvAlertCategory, dailyUpdateCategory])
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                } else {
                    print("Notification permission granted: \(granted)")
                    if granted && self.isHighUVAlertsEnabled {
                        self.scheduleBackgroundTask()
                    }
                }
            }
        }
    }
    
    func registerBackgroundTaskHandlers() {
        if isBackgroundTaskRegistered { return }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: .main) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
        
        isBackgroundTaskRegistered = true
        print("Background task handlers registered successfully")
    }
    
    func registerBackgroundTask() {
        registerBackgroundTaskHandlers()
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
                let locationManager = LocationManager()
                if let location = locationManager.location {
                    print("[BGTask] Got location: \(location)")
                    let weather = try await weatherService.weather(for: location)
                    let uvIndex = Int(weather.currentWeather.uvIndex.value)
                    print("[BGTask] Fetched UV Index: \(uvIndex)")
                    
                    // Check if we should send a notification
                    let shouldNotify = uvIndex >= uvAlertThreshold && 
                                     self.isHighUVAlertsEnabled &&
                                     self.shouldSendNotification(for: uvIndex)
                    
                    if shouldNotify {
                        print("[BGTask] Scheduling High UV Alert for index \(uvIndex)")
                        await self.scheduleUVAlert(uvIndex: uvIndex, location: locationManager.locationName)
                        self.lastNotifiedUVIndex = uvIndex
                        self.lastNotificationDate = Date()
                    } else if uvIndex < uvAlertThreshold {
                        print("[BGTask] UV Index below threshold, resetting lastNotifiedUVIndex")
                        self.lastNotifiedUVIndex = 0
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
    
    private func shouldSendNotification(for uvIndex: Int) -> Bool {
        // Don't send if we've already notified for this UV level
        if uvIndex <= lastNotifiedUVIndex {
            return false
        }
        
        // Don't send if we've sent a notification in the last 30 minutes
        if let lastDate = lastNotificationDate {
            let timeSinceLastNotification = Date().timeIntervalSince(lastDate)
            if timeSinceLastNotification < 30 * 60 { // 30 minutes
                return false
            }
        }
        
        return true
    }
    
    private func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        
        // Schedule for the next 15-minute interval
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
        content.userInfo = ["uvIndex": uvIndex, "location": location]
        
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
        content.categoryIdentifier = "DAILY_UPDATE"
        content.userInfo = ["uvIndex": uvIndex, "location": location]
        
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
        content.categoryIdentifier = "UV_ALERT"
        content.userInfo = ["uvIndex": uvIndex, "location": newLocation]
        
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
        
        // Register background task if high UV alerts are enabled
        if highUVAlerts {
            registerBackgroundTask()
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
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.actionIdentifier
        
        switch identifier {
        case "VIEW_UV_INFO":
            // Handle opening the app to view UV details
            print("User tapped 'View Details' for UV notification")
            // The app will be brought to foreground automatically
            break
        case "DISMISS":
            // Handle dismiss action
            print("User dismissed UV notification")
            break
        default:
            // Handle default tap on notification
            print("User tapped on UV notification")
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Add a public test function to trigger a High UV notification manually
    func testHighUVNotification() {
        print("[Test] Triggering manual High UV notification...")
        Task {
            await self.scheduleUVAlert(uvIndex: uvAlertThreshold, location: "Test Location")
        }
    }
    
    // Function to manually trigger background UV check
    func triggerBackgroundUVCheck() {
        print("[Manual] Triggering background UV check...")
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date()
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Successfully scheduled immediate background task")
        } catch {
            print("Could not schedule immediate background task: \(error.localizedDescription)")
        }
    }
} 
