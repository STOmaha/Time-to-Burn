import Foundation
import UserNotifications
import Supabase
import UIKit

// MARK: - Push Notification Service
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    
    // MARK: - Properties
    @Published var isRegistered = false
    @Published var deviceToken: String?
    @Published var error: Error?
    
    private let supabaseService: SupabaseService
    
    // MARK: - Initialization
    private init() {
        print("🔔 [PushNotificationService] 🚀 Initializing...")
        self.supabaseService = SupabaseService.shared
        setupNotificationDelegate()
    }
    
    // MARK: - Setup
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    // MARK: - Permission Request
    
    @MainActor
    func requestPermission() async -> Bool {
        print("🔔 [PushNotificationService] 📱 Requesting push notification permission...")
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            
            print("🔔 [PushNotificationService] 📱 Permission granted: \(granted)")
            
            if granted {
                await registerForRemoteNotifications()
            }
            
            return granted
        } catch {
            self.error = error
            print("🔔 [PushNotificationService] ❌ Permission request failed: \(error)")
            return false
        }
    }
    
    // MARK: - Device Registration
    
    @MainActor
    func registerForRemoteNotifications() async {
        print("🔔 [PushNotificationService] 📱 Registering for remote notifications...")
        
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        Task { @MainActor in
            self.deviceToken = tokenString
            print("🔔 [PushNotificationService] ✅ Device token received: \(tokenString)")
            
            // Register device token with Supabase
            await registerDeviceTokenWithSupabase(tokenString)
        }
    }
    
    func handleRegistrationError(_ error: Error) {
        Task { @MainActor in
            self.error = error
            print("🔔 [PushNotificationService] ❌ Registration failed: \(error)")
        }
    }
    
    // MARK: - Supabase Integration
    
    private func registerDeviceTokenWithSupabase(_ token: String) async {
        print("🔔 [PushNotificationService] 🌐 Registering device token with Supabase...")
        
        do {
            try await supabaseService.registerDeviceToken(token)
            
            await MainActor.run {
                self.isRegistered = true
                print("🔔 [PushNotificationService] ✅ Device token registered with Supabase")
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("🔔 [PushNotificationService] ❌ Failed to register device token: \(error)")
            }
        }
    }
    
    // MARK: - Notification Types
    
    enum NotificationType: String, CaseIterable {
        case uvAlert = "uv_alert"
        case timerReminder = "timer_reminder"
        case dailySummary = "daily_summary"
        case sunscreenReminder = "sunscreen_reminder"
        case weatherUpdate = "weather_update"
        
        var title: String {
            switch self {
            case .uvAlert: return "UV Alert"
            case .timerReminder: return "Timer Reminder"
            case .dailySummary: return "Daily Summary"
            case .sunscreenReminder: return "Sunscreen Reminder"
            case .weatherUpdate: return "Weather Update"
            }
        }
        
        var description: String {
            switch self {
            case .uvAlert: return "High UV index detected"
            case .timerReminder: return "Time to check your sun exposure"
            case .dailySummary: return "Your daily sun exposure summary"
            case .sunscreenReminder: return "Time to reapply sunscreen"
            case .weatherUpdate: return "Weather conditions have changed"
            }
        }
    }
    
    // MARK: - Local Notification Scheduling
    
    func scheduleLocalNotification(
        type: NotificationType,
        title: String,
        body: String,
        timeInterval: TimeInterval? = nil,
        date: Date? = nil,
        repeats: Bool = false
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = type.rawValue
        
        var trigger: UNNotificationTrigger?
        
        if let timeInterval = timeInterval {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: repeats)
        } else if let date = date {
            trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: repeats)
        }
        
        guard let trigger = trigger else {
            print("🔔 [PushNotificationService] ❌ No trigger specified for notification")
            return
        }
        
        let request = UNNotificationRequest(
            identifier: "\(type.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [PushNotificationService] ❌ Failed to schedule notification: \(error)")
            } else {
                print("🔔 [PushNotificationService] ✅ Local notification scheduled: \(type.title)")
            }
        }
    }
    
    // MARK: - UV Alert Notifications
    
    func scheduleUVAlert(uvIndex: Int, location: String) {
        let title = "High UV Alert"
        let body = "UV Index is \(uvIndex) in \(location). Time to protect your skin!"
        
        scheduleLocalNotification(
            type: .uvAlert,
            title: title,
            body: body,
            timeInterval: 1 // Send immediately
        )
    }
    
    // MARK: - Timer Reminder Notifications
    
    func scheduleTimerReminder(minutesRemaining: Int) {
        let title = "Sun Exposure Timer"
        let body = "You have \(minutesRemaining) minutes remaining in the sun. Consider seeking shade soon."
        
        scheduleLocalNotification(
            type: .timerReminder,
            title: title,
            body: body,
            timeInterval: 1
        )
    }
    
    // MARK: - Daily Summary Notifications
    
    func scheduleDailySummary(totalExposure: Int, uvIndex: Int) {
        let hours = totalExposure / 3600
        let minutes = (totalExposure % 3600) / 60
        
        let title = "Daily Sun Exposure Summary"
        let body = "Today you spent \(hours)h \(minutes)m in the sun with UV Index up to \(uvIndex)."
        
        scheduleLocalNotification(
            type: .dailySummary,
            title: title,
            body: body,
            timeInterval: 1
        )
    }
    
    // MARK: - Sunscreen Reminder Notifications
    
    func scheduleSunscreenReminder() {
        let title = "Sunscreen Reminder"
        let body = "It's time to reapply your sunscreen for continued protection."
        
        scheduleLocalNotification(
            type: .sunscreenReminder,
            title: title,
            body: body,
            timeInterval: 1
        )
    }
    
    // MARK: - Cleanup
    
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🔔 [PushNotificationService] 🧹 All pending notifications removed")
    }
    
    func removeNotifications(withType type: NotificationType) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.content.categoryIdentifier == type.rawValue }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            print("🔔 [PushNotificationService] 🧹 Removed \(identifiersToRemove.count) notifications of type: \(type.title)")
        }
    }
} 