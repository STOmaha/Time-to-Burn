import Foundation
import UserNotifications

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .timeSensitive]
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
    
    func scheduleUVAlert(uvIndex: Int, location: String) {
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
            trigger: nil
        )
        
        // Schedule the notification
        UNUserNotificationCenter.current().add(request)
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