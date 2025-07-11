import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var notificationSettings = NotificationSettings()
    
    private init() {
        loadSettings()
        checkAuthorizationStatus()
        setupNotificationCategories()
    }
    
    // MARK: - Authorization
    func requestNotificationPermission() async -> Bool {
        print("🔔 [NotificationManager] Requesting notification permission...")
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            await MainActor.run {
                self.isAuthorized = granted
                print("🔔 [NotificationManager] Notification permission result: \(granted)")
            }
            return granted
        } catch {
            print("🔔 [NotificationManager] Error requesting permission - \(error)")
            return false
        }
    }
    
    func forceRequestNotificationPermission() async {
        print("🔔 [NotificationManager] Force requesting notification permission...")
        let granted = await requestNotificationPermission()
        if granted {
            print("🔔 [NotificationManager] ✅ Notification permission granted, setting up categories...")
            setupNotificationCategories()
        } else {
            print("🔔 [NotificationManager] ❌ Notification permission denied")
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized || 
                                   settings.authorizationStatus == .provisional
                print("🔔 [NotificationManager] Authorization status: \(settings.authorizationStatus.rawValue), isAuthorized: \(self.isAuthorized)")
            }
        }
    }
    
    // MARK: - Sunscreen Reapply Notifications
    func scheduleSunscreenReminder(at date: Date) {
        print("🔔 [NotificationManager] Attempting to schedule sunscreen reminder. isAuthorized: \(isAuthorized), sunscreenRemindersEnabled: \(notificationSettings.sunscreenRemindersEnabled)")
        guard isAuthorized && notificationSettings.sunscreenRemindersEnabled else { 
            print("🔔 [NotificationManager] ❌ Cannot schedule sunscreen reminder - not authorized or disabled")
            return 
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Time to Reapply Sunscreen! ☀️"
        content.body = "It's been 2 hours since your last application. Reapply sunscreen for continued protection."
        content.sound = .default
        content.categoryIdentifier = "SUNSCREEN_REMINDER"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "sunscreen_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Error scheduling sunscreen reminder - \(error)")
            } else {
                print("NotificationManager: Sunscreen reminder scheduled for \(date)")
            }
        }
    }
    
    func cancelSunscreenReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["sunscreen_reminder"])
    }
    
    func scheduleSunscreenExpiredAlert() {
        print("🔔 [NotificationManager] Attempting to schedule sunscreen expired alert. isAuthorized: \(isAuthorized), sunscreenRemindersEnabled: \(notificationSettings.sunscreenRemindersEnabled)")
        guard isAuthorized && notificationSettings.sunscreenRemindersEnabled else { 
            print("🔔 [NotificationManager] ❌ Cannot schedule sunscreen expired alert - not authorized or disabled")
            return 
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🚨 Sunscreen Timer Expired!"
        content.body = "Your sunscreen protection has expired. Reapply sunscreen now for continued protection."
        content.sound = .default
        content.categoryIdentifier = "SUNSCREEN_EXPIRED"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "sunscreen_expired_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Error scheduling sunscreen expired alert - \(error)")
            } else {
                print("NotificationManager: Sunscreen expired alert scheduled")
            }
        }
    }
    
    // MARK: - Exposure Warning Notifications
    func scheduleExposureWarning(warningType: ExposureWarningType, timeToBurn: Int) {
        print("🔔 [NotificationManager] Attempting to schedule exposure warning. isAuthorized: \(isAuthorized), exposureWarningsEnabled: \(notificationSettings.exposureWarningsEnabled)")
        guard isAuthorized && notificationSettings.exposureWarningsEnabled else { 
            print("🔔 [NotificationManager] ❌ Cannot schedule exposure warning - not authorized or disabled")
            return 
        }
        
        let content = UNMutableNotificationContent()
        
        switch warningType {
        case .approaching:
            content.title = "⚠️ Sun Exposure Warning"
            content.body = "You're approaching your safe exposure limit. Consider seeking shade soon."
        case .exceeded:
            content.title = "🚨 Sun Exposure Exceeded!"
            content.body = "You've exceeded your safe exposure time. Seek shade immediately and avoid further sun exposure."
        }
        
        content.sound = .default
        content.categoryIdentifier = "EXPOSURE_WARNING"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "exposure_warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Error scheduling exposure warning - \(error)")
            } else {
                print("NotificationManager: Exposure warning scheduled")
            }
        }
    }
    
    // MARK: - UV Threshold Notifications
    func scheduleUVThresholdAlert(uvIndex: Int, threshold: Int) {
        guard isAuthorized && notificationSettings.uvThresholdAlertsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🌡️ High UV Alert"
        content.body = "UV Index is \(uvIndex) (above your threshold of \(threshold)). Take extra precautions!"
        content.sound = .default
        content.categoryIdentifier = "UV_THRESHOLD_ALERT"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "uv_threshold_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationManager: Error scheduling UV threshold alert - \(error)")
            } else {
                print("NotificationManager: UV threshold alert scheduled")
            }
        }
    }
    
    // MARK: - Daily Summary Notifications
    func scheduleDailySummary(at date: Date, totalExposure: TimeInterval) {
        guard isAuthorized && notificationSettings.dailySummaryEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Daily Sun Exposure Summary"
        
        // If totalExposure is 0, we'll use a placeholder that will be updated
        // The actual exposure time will be calculated when the notification is delivered
        let hours = Int(totalExposure) / 3600
        let minutes = Int(totalExposure) / 60 % 60
        
        if totalExposure > 0 {
            if hours > 0 {
                content.body = "Today you spent \(hours)h \(minutes)m in the sun. Great job staying protected!"
            } else {
                content.body = "Today you spent \(minutes)m in the sun. Great job staying protected!"
            }
        } else {
            content.body = "Check your daily sun exposure summary. Stay protected tomorrow!"
        }
        
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"
        
        // Schedule for 8 PM
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 20
        components.minute = 0
        
        if let targetDate = Calendar.current.date(from: components) {
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "daily_summary_\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("NotificationManager: Error scheduling daily summary - \(error)")
                } else {
                    print("NotificationManager: Daily summary scheduled for \(targetDate)")
                }
            }
        }
    }
    
    // MARK: - Settings Management
    func updateSettings(_ settings: NotificationSettings) {
        self.notificationSettings = settings
        saveSettings()
        
        // Handle daily summary scheduling when setting changes
        if settings.dailySummaryEnabled {
            scheduleDailySummaryIfNeeded()
        } else {
            // Cancel any existing daily summary notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_summary_\(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)"])
        }
    }
    
    // MARK: - Daily Summary Management
    func scheduleDailySummaryIfNeeded() {
        guard notificationSettings.dailySummaryEnabled else { return }
        
        // Schedule for today at 8 PM with current exposure time
        // The actual exposure time will be calculated when the notification fires
        scheduleDailySummary(at: Date(), totalExposure: 0)
        
        print("📊 [NotificationManager] ✅ Daily summary scheduled for 8:00 PM")
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        notificationSettings = NotificationSettings(
            sunscreenRemindersEnabled: defaults.bool(forKey: "sunscreenRemindersEnabled"),
            exposureWarningsEnabled: defaults.bool(forKey: "exposureWarningsEnabled"),
            uvThresholdAlertsEnabled: defaults.bool(forKey: "uvThresholdAlertsEnabled"),
            dailySummaryEnabled: defaults.bool(forKey: "dailySummaryEnabled"),
            uvThreshold: defaults.integer(forKey: "uvAlertThreshold") == 0 ? 6 : defaults.integer(forKey: "uvAlertThreshold")
        )
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(notificationSettings.sunscreenRemindersEnabled, forKey: "sunscreenRemindersEnabled")
        defaults.set(notificationSettings.exposureWarningsEnabled, forKey: "exposureWarningsEnabled")
        defaults.set(notificationSettings.uvThresholdAlertsEnabled, forKey: "uvThresholdAlertsEnabled")
        defaults.set(notificationSettings.dailySummaryEnabled, forKey: "dailySummaryEnabled")
        defaults.set(notificationSettings.uvThreshold, forKey: "uvAlertThreshold")
    }
    
    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let sunscreenAction = UNNotificationAction(
            identifier: "APPLY_SUNSCREEN",
            title: "Apply Sunscreen",
            options: [.foreground]
        )
        
        let sunscreenCategory = UNNotificationCategory(
            identifier: "SUNSCREEN_REMINDER",
            actions: [sunscreenAction],
            intentIdentifiers: [],
            options: []
        )
        
        let sunscreenExpiredAction = UNNotificationAction(
            identifier: "REAPPLY_SUNSCREEN",
            title: "Reapply Sunscreen",
            options: [.foreground]
        )
        
        let sunscreenExpiredCategory = UNNotificationCategory(
            identifier: "SUNSCREEN_EXPIRED",
            actions: [sunscreenExpiredAction],
            intentIdentifiers: [],
            options: []
        )
        
        let exposureAction = UNNotificationAction(
            identifier: "SEEK_SHADE",
            title: "Seek Shade",
            options: [.foreground]
        )
        
        let exposureCategory = UNNotificationCategory(
            identifier: "EXPOSURE_WARNING",
            actions: [exposureAction],
            intentIdentifiers: [],
            options: []
        )
        
        let uvAction = UNNotificationAction(
            identifier: "VIEW_UV_DATA",
            title: "View UV Data",
            options: [.foreground]
        )
        
        let uvCategory = UNNotificationCategory(
            identifier: "UV_THRESHOLD_ALERT",
            actions: [uvAction],
            intentIdentifiers: [],
            options: []
        )
        
        let summaryAction = UNNotificationAction(
            identifier: "VIEW_SUMMARY",
            title: "View Summary",
            options: [.foreground]
        )
        
        let summaryCategory = UNNotificationCategory(
            identifier: "DAILY_SUMMARY",
            actions: [summaryAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            sunscreenCategory,
            sunscreenExpiredCategory,
            exposureCategory,
            uvCategory,
            summaryCategory
        ])
    }
    
    // MARK: - Test Notifications
    func sendTestNotification() {
        print("🔔 [NotificationManager] Sending test notification...")
        
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "This is a test notification to verify the notification system is working."
        content.sound = .default
        content.categoryIdentifier = "TEST"
        content.badge = 1
        
        // Send immediate notification (no trigger delay)
        let request = UNNotificationRequest(
            identifier: "test_notification_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error sending test notification - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Test notification scheduled successfully")
                
                // Force immediate delivery by presenting it locally
                DispatchQueue.main.async {
                    self.presentLocalNotification(content: content)
                }
            }
        }
    }
    
    func sendImmediateUVThresholdAlert(uvIndex: Int, threshold: Int) {
        print("🔔 [NotificationManager] Sending immediate UV threshold alert...")
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ High UV Alert"
        content.body = "UV Index is \(uvIndex), above your threshold of \(threshold). Time to protect yourself!"
        content.sound = .default
        content.categoryIdentifier = "UV_THRESHOLD"
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "uv_threshold_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error sending UV threshold alert - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ UV threshold alert sent successfully")
                
                // Force immediate delivery by presenting it locally
                DispatchQueue.main.async {
                    self.presentLocalNotification(content: content)
                }
            }
        }
    }
    
    func sendImmediateSunscreenReminder() {
        print("🔔 [NotificationManager] Sending immediate sunscreen reminder...")
        
        let content = UNMutableNotificationContent()
        content.title = "🧴 Sunscreen Reminder"
        content.body = "It's time to reapply your sunscreen to stay protected!"
        content.sound = .default
        content.categoryIdentifier = "SUNSCREEN_REMINDER"
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "sunscreen_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error sending sunscreen reminder - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Sunscreen reminder sent successfully")
                
                // Force immediate delivery by presenting it locally
                DispatchQueue.main.async {
                    self.presentLocalNotification(content: content)
                }
            }
        }
    }
    
    func sendImmediateSunscreenExpiredAlert() {
        print("🔔 [NotificationManager] Sending immediate sunscreen expired alert...")
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ Sunscreen Expired"
        content.body = "Your sunscreen protection has expired! Reapply now to stay protected."
        content.sound = .default
        content.categoryIdentifier = "SUNSCREEN_EXPIRED"
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "sunscreen_expired_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error sending sunscreen expired alert - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Sunscreen expired alert sent successfully")
                
                // Force immediate delivery by presenting it locally
                DispatchQueue.main.async {
                    self.presentLocalNotification(content: content)
                }
            }
        }
    }
    
    func sendImmediateExposureWarning(warningType: ExposureWarningType, timeToBurn: Int) {
        print("🔔 [NotificationManager] Sending immediate exposure warning...")
        
        let content = UNMutableNotificationContent()
        content.title = "☀️ Exposure Warning"
        
        let minutes = timeToBurn / 60
        let seconds = timeToBurn % 60
        
        switch warningType {
        case .approaching:
            content.body = "You're approaching your daily limit. \(minutes)m \(seconds)s remaining."
        case .exceeded:
            content.body = "⚠️ You've exceeded your daily exposure limit! Seek shade immediately."
        }
        
        content.sound = .default
        content.categoryIdentifier = "EXPOSURE_WARNING"
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "exposure_warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error sending exposure warning - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Exposure warning sent successfully")
                
                // Force immediate delivery by presenting it locally
                DispatchQueue.main.async {
                    self.presentLocalNotification(content: content)
                }
            }
        }
    }
    
    func sendImmediateDailySummary(totalExposure: TimeInterval) {
        print("🔔 [NotificationManager] Sending immediate daily summary...")
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Daily Sun Exposure Summary"
        
        let hours = Int(totalExposure) / 3600
        let minutes = Int(totalExposure) / 60 % 60
        
        if hours > 0 {
            content.body = "Today you spent \(hours)h \(minutes)m in the sun. Great job staying protected!"
        } else {
            content.body = "Today you spent \(minutes)m in the sun. Great job staying protected!"
        }
        
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: "daily_summary_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error sending daily summary - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Daily summary sent successfully")
                
                // Force immediate delivery by presenting it locally
                DispatchQueue.main.async {
                    self.presentLocalNotification(content: content)
                }
            }
        }
    }
    
    // MARK: - Cleanup
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error clearing badge - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Badge cleared successfully")
            }
        }
    }
    
    // MARK: - Local Notification Presentation
    private func presentLocalNotification(content: UNNotificationContent) {
        // Create a local notification that will show immediately
        let localNotification = UNNotificationRequest(
            identifier: "local_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(localNotification) { error in
            if let error = error {
                print("🔔 [NotificationManager] ❌ Error presenting local notification - \(error)")
            } else {
                print("🔔 [NotificationManager] ✅ Local notification presented successfully")
            }
        }
    }
}

// MARK: - Supporting Types
enum ExposureWarningType {
    case approaching
    case exceeded
}

struct NotificationSettings: Equatable {
    var sunscreenRemindersEnabled: Bool = true
    var exposureWarningsEnabled: Bool = true
    var uvThresholdAlertsEnabled: Bool = true
    var dailySummaryEnabled: Bool = false
    var uvThreshold: Int = 6
} 