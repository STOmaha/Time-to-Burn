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
    }
    
    // MARK: - Authorization
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("NotificationManager: Error requesting permission - \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized || 
                                   settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - Sunscreen Reapply Notifications
    func scheduleSunscreenReminder(at date: Date) {
        guard isAuthorized && notificationSettings.sunscreenRemindersEnabled else { return }
        
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
    
    // MARK: - Exposure Warning Notifications
    func scheduleExposureWarning(warningType: ExposureWarningType, timeToBurn: Int) {
        guard isAuthorized && notificationSettings.exposureWarningsEnabled else { return }
        
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
        
        let hours = Int(totalExposure) / 3600
        let minutes = Int(totalExposure) / 60 % 60
        
        if hours > 0 {
            content.body = "Today you spent \(hours)h \(minutes)m in the sun. Great job staying protected!"
        } else {
            content.body = "Today you spent \(minutes)m in the sun. Great job staying protected!"
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
            exposureCategory,
            uvCategory,
            summaryCategory
        ])
    }
    
    // MARK: - Cleanup
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
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