import Foundation
import UserNotifications
import UIKit

@MainActor
class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    
    // MARK: - Properties
    @Published var isRegistered = false
    @Published var deviceToken: String?
    @Published var error: Error?
    @Published var isLoading = false
    
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
            case .uvAlert: return "Get notified when UV levels are high"
            case .timerReminder: return "Reminders about your sun exposure timer"
            case .dailySummary: return "Daily summary of your sun exposure"
            case .sunscreenReminder: return "Reminders to reapply sunscreen"
            case .weatherUpdate: return "Weather and UV updates"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        // Note: NotificationDelegate is set up in Time_to_BurnApp.swift init
        // to avoid circular dependency
    }
    
    // MARK: - Permission Request
    func requestPermission() async -> Bool {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                self.isRegistered = granted
                self.isLoading = false
                
                if granted {
                    print("🔔 [PushNotificationService] ✅ Push notification permission granted")
                    self.registerForRemoteNotifications()
                } else {
                    print("🔔 [PushNotificationService] ❌ Push notification permission denied")
                }
            }
            
            return granted
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
                print("🔔 [PushNotificationService] ❌ Error requesting permission: \(error.localizedDescription)")
            }
            return false
        }
    }
    
    // MARK: - Remote Notification Registration
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - Device Token Handling
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        print("🔔 [PushNotificationService] 📱 Device token received: \(tokenString)")
        
        // Register device token with Supabase
        Task {
            await registerTokenWithSupabase(tokenString)
        }
    }
    
    /// Register device token with Supabase
    private func registerTokenWithSupabase(_ token: String) async {
        // Only register if user is authenticated
        guard SupabaseService.shared.isAuthenticated else {
            print("🔔 [PushNotificationService] ⏳ Waiting for authentication to register token")
            // Store token locally to register after auth
            UserDefaults.standard.set(token, forKey: "pendingDeviceToken")
            return
        }
        
        print("🔔 [PushNotificationService] 📤 Registering device token with Supabase...")
        
        // Gather device info
        let deviceInfo = DeviceInfo(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion
        )
        
        do {
            try await SupabaseService.shared.registerDeviceToken(token, deviceInfo: deviceInfo)
            print("🔔 [PushNotificationService] ✅ Device token registered with Supabase")
            
            // Clear pending token
            UserDefaults.standard.removeObject(forKey: "pendingDeviceToken")
            
        } catch {
            print("🔔 [PushNotificationService] ❌ Failed to register token with Supabase: \(error.localizedDescription)")
        }
    }
    
    /// Register pending device token after authentication
    func registerPendingToken() async {
        if let pendingToken = UserDefaults.standard.string(forKey: "pendingDeviceToken") {
            print("🔔 [PushNotificationService] 🔄 Registering pending device token...")
            await registerTokenWithSupabase(pendingToken)
        }
    }
    
    // MARK: - Error Handling
    func handleRegistrationError(_ error: Error) {
        self.error = error
        print("🔔 [PushNotificationService] ❌ Registration error: \(error.localizedDescription)")
    }
    
    // MARK: - Notification Categories
    func setupNotificationCategories() {
        let categories = NotificationType.allCases.map { type in
            UNNotificationCategory(
                identifier: type.rawValue,
                actions: [
                    UNNotificationAction(
                        identifier: "VIEW",
                        title: "View",
                        options: [.foreground]
                    ),
                    UNNotificationAction(
                        identifier: "DISMISS",
                        title: "Dismiss",
                        options: [.destructive]
                    )
                ],
                intentIdentifiers: [],
                options: []
            )
        }
        
        UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
        print("🔔 [PushNotificationService] ✅ Notification categories set up")
    }
    
    // MARK: - Test Methods
    func testPushNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Test UV Alert"
        content.body = "This is a test push notification"
        content.sound = .default
        content.categoryIdentifier = NotificationType.uvAlert.rawValue
        content.userInfo = ["type": "test"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test_push", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 [PushNotificationService] ❌ Test notification failed: \(error.localizedDescription)")
            } else {
                print("🔔 [PushNotificationService] ✅ Test notification scheduled")
            }
        }
    }
}

// Note: DeviceInfo is defined in SupabaseService.swift
