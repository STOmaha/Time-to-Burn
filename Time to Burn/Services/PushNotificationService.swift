// import Foundation
// import UserNotifications
// import UIKit

// @MainActor
// class PushNotificationService: ObservableObject {
//     static let shared = PushNotificationService()
    
//     // MARK: - Properties
//     @Published var isRegistered = false
//     @Published var deviceToken: String?
//     @Published var error: Error?
//     @Published var isLoading = false
    
//     // MARK: - Notification Types
//     enum NotificationType: String, CaseIterable {
//         case uvAlert = "uv_alert"
//         case timerReminder = "timer_reminder"
//         case dailySummary = "daily_summary"
//         case sunscreenReminder = "sunscreen_reminder"
//         case weatherUpdate = "weather_update"
        
//         var title: String {
//             switch self {
//             case .uvAlert: return "UV Alert"
//             case .timerReminder: return "Timer Reminder"
//             case .dailySummary: return "Daily Summary"
//             case .sunscreenReminder: return "Sunscreen Reminder"
//             case .weatherUpdate: return "Weather Update"
//             }
//         }
        
//         var description: String {
//             switch self {
//             case .uvAlert: return "Get notified when UV levels are high"
//             case .timerReminder: return "Reminders about your sun exposure timer"
//             case .dailySummary: return "Daily summary of your sun exposure"
//             case .sunscreenReminder: return "Reminders to reapply sunscreen"
//             case .weatherUpdate: return "Weather and UV updates"
//             }
//         }
//     }
    
//     // MARK: - Initialization
//     private init() {
//         setupNotificationDelegate()
//     }
    
//     private func setupNotificationDelegate() {
//         UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
//     }
    
//     // MARK: - Permission Request
//     func requestPermission() async {
//         await MainActor.run {
//             isLoading = true
//             error = nil
//         }
        
//         do {
//             let granted = try await UNUserNotificationCenter.current().requestAuthorization(
//                 options: [.alert, .badge, .sound]
//             )
            
//             await MainActor.run {
//                 self.isRegistered = granted
//                 self.isLoading = false
                
//                 if granted {
//                     print("🔔 [PushNotificationService] ✅ Push notification permission granted")
//                     await self.registerForRemoteNotifications()
//                 } else {
//                     print("🔔 [PushNotificationService] ❌ Push notification permission denied")
//                 }
//             }
            
//         } catch {
//             await MainActor.run {
//                 self.error = error
//                 self.isLoading = false
//                 print("🔔 [PushNotificationService] ❌ Error requesting permission: \(error.localizedDescription)")
//             }
//         }
//     }
    
//     // MARK: - Remote Notification Registration
//     private func registerForRemoteNotifications() async {
//         await MainActor.run {
//             UIApplication.shared.registerForRemoteNotifications()
//         }
//     }
    
//     // MARK: - Device Token Handling
//     func handleDeviceToken(_ deviceToken: Data) {
//         let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
//         self.deviceToken = tokenString
        
//         print("🔔 [PushNotificationService] 📱 Device token received: \(tokenString)")
        
//         // Store token locally (Supabase removed)
//         print("🔔 [PushNotificationService] ✅ Device token stored locally")
//     }
//     }
    
//     // MARK: - Error Handling
//     func handleRegistrationError(_ error: Error) {
//         self.error = error
//         print("🔔 [PushNotificationService] ❌ Registration error: \(error.localizedDescription)")
//     }
    
//     // MARK: - Notification Categories
//     func setupNotificationCategories() {
//         let categories = NotificationType.allCases.map { type in
//             UNNotificationCategory(
//                 identifier: type.rawValue,
//                 actions: [
//                     UNNotificationAction(
//                         identifier: "VIEW",
//                         title: "View",
//                         options: [.foreground]
//                     ),
//                     UNNotificationAction(
//                         identifier: "DISMISS",
//                         title: "Dismiss",
//                         options: [.destructive]
//                     )
//                 ],
//                 intentIdentifiers: [],
//                 options: []
//             )
//         }
        
//         UNUserNotificationCenter.current().setNotificationCategories(Set(categories))
//         print("🔔 [PushNotificationService] ✅ Notification categories set up")
//     }
    
//     // MARK: - Test Methods
//     func testPushNotification() {
//         let content = UNMutableNotificationContent()
//         content.title = "Test UV Alert"
//         content.body = "This is a test push notification"
//         content.sound = .default
//         content.categoryIdentifier = NotificationType.uvAlert.rawValue
//         content.userInfo = ["type": "test"]
        
//         let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
//         let request = UNNotificationRequest(identifier: "test_push", content: content, trigger: trigger)
        
//         UNUserNotificationCenter.current().add(request) { error in
//             if let error = error {
//                 print("🔔 [PushNotificationService] ❌ Test notification failed: \(error.localizedDescription)")
//             } else {
//                 print("🔔 [PushNotificationService] ✅ Test notification scheduled")
//             }
//         }
//     }
// } 