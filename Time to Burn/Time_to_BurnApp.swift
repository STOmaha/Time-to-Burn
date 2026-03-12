//
//  Time_to_BurnApp.swift
//  Time to Burn
//
//  Created by Steven Taylor on 6/12/25.
//

import SwiftUI
import WeatherKit
import UserNotifications
// TODO: Re-enable Firebase imports after adding Firebase SDK
// import Firebase
// import FirebaseMessaging

@main
struct Time_to_BurnApp: App {
    // Connect NotificationDelegate as the UIApplicationDelegate for push notification handling
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) var appDelegate

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var weatherViewModel: WeatherViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var authenticationManager = AuthenticationManager.shared
    @StateObject private var pushNotificationService = PushNotificationService.shared
    
    init() {
        // Use shared LocationManager instance
        let locationManager = LocationManager.shared
        _locationManager = StateObject(wrappedValue: locationManager)
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(locationManager: locationManager))
        _notificationManager = StateObject(wrappedValue: NotificationManager.shared)
        _onboardingManager = StateObject(wrappedValue: OnboardingManager.shared)
        _settingsManager = StateObject(wrappedValue: SettingsManager.shared)
        _authenticationManager = StateObject(wrappedValue: AuthenticationManager.shared)
        _pushNotificationService = StateObject(wrappedValue: PushNotificationService.shared)
        
        // Configure UnitConverter with SettingsManager
        UnitConverter.shared.configure(with: SettingsManager.shared)
        
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Setup app delegate for push notifications
        // if UIApplication.shared.delegate is NotificationDelegate {
        //     // Already set
        // } else {
        //     UIApplication.shared.delegate = NotificationDelegate.shared
        // }
        
        logSuccess(.app, "Time to Burn app initialization complete! 🎉", data: [
            "Components": "Location, Weather, Notifications, Onboarding, Settings",
            "Unit System": "Configured",
            "Ready": "✅"
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingManager.isOnboardingComplete {
                ContentView()
                    .environmentObject(locationManager)
                    .environmentObject(weatherViewModel)
                    .environmentObject(notificationManager)
                    .environmentObject(settingsManager)
                    .environmentObject(timerViewModel)
                    .environmentObject(authenticationManager)
                    .environmentObject(pushNotificationService)
                    .onAppear {
                        // NOTE: Notification permissions are requested during onboarding
                        // Here we just check status and schedule daily refresh if already authorized
                        if notificationManager.isAuthorized {
                            notificationManager.scheduleDailyWeatherRefresh()
                        }

                        // Set up TimerViewModel dependencies for Live Activity and widget data
                        timerViewModel.setDependencies(locationManager: locationManager, weatherViewModel: weatherViewModel)

                        // Set up Watch Connectivity
                        WatchConnectivityManager.shared.configure(with: timerViewModel)

                        // Weather data will be fetched automatically when location is available
                        logInfo(.app, "Main app interface appeared, weather system active")
                    }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            // Refresh weather data when app becomes active
                            // WeatherViewModel has debouncing to prevent cascade loops
                            Task {
                                await weatherViewModel.refreshData()
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("applySunscreenFromLiveActivity"))) { _ in
                            timerViewModel.applySunscreenFromLiveActivity()
                        }

            } else {
                OnboardingView()
                    .environmentObject(locationManager)
                    .environmentObject(weatherViewModel)
                    .environmentObject(notificationManager)
                    .environmentObject(settingsManager)
                    .environmentObject(authenticationManager)
            }
        }
        .onChange(of: onboardingManager.isOnboardingComplete) { _, isComplete in
            if isComplete {
                // Refresh UV data when onboarding completes
                logInfo(.app, "Onboarding completed, triggering UV data refresh")
                Task {
                    await weatherViewModel.refreshData()
                }
            }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    static let shared = NotificationDelegate()

    // Access PushNotificationService lazily to avoid circular dependency
    private var pushNotificationService: PushNotificationService {
        PushNotificationService.shared
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        let categoryIdentifier = response.notification.request.content.categoryIdentifier

        print("🔔 [NotificationDelegate] Notification received: \(identifier), action: \(actionIdentifier), category: \(categoryIdentifier)")

        // Handle daily weather refresh notification
        if identifier == "daily_weather_refresh" || actionIdentifier == "REFRESH_WEATHER" {
            print("🔔 [NotificationDelegate] 🌤️ Daily weather refresh triggered")

            // Post notification to trigger weather refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
            }
        }

        // Handle START_TIMER action from UV threshold alerts
        if actionIdentifier == "START_TIMER" {
            print("🔔 [NotificationDelegate] ⏱️ Start Timer action triggered from UV alert")
            DispatchQueue.main.async {
                // Start the timer and navigate to Risk Tab
                NotificationCenter.default.post(name: Notification.Name("startTimerFromNotification"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("openRiskTab"), object: nil)
            }
        }

        // Handle VIEW_UV_DATA action
        if actionIdentifier == "VIEW_UV_DATA" {
            print("🔔 [NotificationDelegate] 📊 View UV Data action triggered")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("openRiskTab"), object: nil)
            }
        }

        // Handle UV_DANGER_ALERT category actions (4 options)
        if categoryIdentifier == "UV_DANGER_ALERT" {
            handleUVDangerAction(actionIdentifier)
        }

        // Handle push notification types
        if let notificationType = PushNotificationService.NotificationType(rawValue: categoryIdentifier) {
            handlePushNotification(notificationType, actionIdentifier: actionIdentifier)
        }

        completionHandler()
    }

    private func handlePushNotification(_ type: PushNotificationService.NotificationType, actionIdentifier: String) {
        print("🔔 [NotificationDelegate] 📱 Handling push notification: \(type.title)")

        switch type {
        case .uvAlert:
            // Handle UV alert - could open UV tab
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("openUVTab"), object: nil)
            }

        case .timerReminder:
            // Handle timer reminder - could open timer tab
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("openTimerTab"), object: nil)
            }

        case .dailySummary:
            // Handle daily summary - could open summary view
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("openDailySummary"), object: nil)
            }

        case .sunscreenReminder:
            // Handle sunscreen reminder
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("sunscreenReminder"), object: nil)
            }

        case .weatherUpdate:
            // Handle weather update - could refresh weather data
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("refreshWeatherData"), object: nil)
            }
        }
    }

    // MARK: - UV Danger Alert Action Handler
    /// Handles the 4 actions from UV_DANGER_ALERT notifications
    private func handleUVDangerAction(_ actionIdentifier: String) {
        switch actionIdentifier {
        case "APPLY_SUNSCREEN_FROM_DANGER":
            print("🔔 [NotificationDelegate] 🧴 Apply Sunscreen action triggered from UV Danger alert")
            DispatchQueue.main.async {
                // Apply sunscreen and navigate to Risk tab
                NotificationCenter.default.post(name: Notification.Name("applySunscreenFromNotification"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("openRiskTab"), object: nil)
            }

        case "START_UV_TIMER":
            print("🔔 [NotificationDelegate] ⏱️ Start UV Timer action triggered from UV Danger alert")
            DispatchQueue.main.async {
                // Start the UV exposure timer and navigate to Risk tab
                NotificationCenter.default.post(name: Notification.Name("startTimerFromNotification"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("openRiskTab"), object: nil)
            }

        case "START_SUNSCREEN_TIMER":
            print("🔔 [NotificationDelegate] ⏰ Start Sunscreen Timer action triggered from UV Danger alert")
            DispatchQueue.main.async {
                // Apply sunscreen (starts 2-hour countdown) and navigate to Risk tab
                NotificationCenter.default.post(name: Notification.Name("applySunscreenFromNotification"), object: nil)
                NotificationCenter.default.post(name: Notification.Name("openRiskTab"), object: nil)
            }

        case "IGNORE_FOR_DAY":
            print("🔔 [NotificationDelegate] 🔕 Ignore for Day action triggered")
            // Sync to Supabase to silence notifications for rest of day
            Task {
                await SupabaseService.shared.setIgnoreNotificationsForToday()
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            print("🔔 [NotificationDelegate] User tapped UV Danger notification")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("openRiskTab"), object: nil)
            }

        default:
            break
        }
    }

    // MARK: - UIApplicationDelegate Methods for Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🔔 [NotificationDelegate] 📱 Device token received: \(tokenString)")

        // Register device token with Supabase
        pushNotificationService.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 [NotificationDelegate] ❌ Failed to register for remote notifications: \(error)")
        pushNotificationService.handleRegistrationError(error)
    }

    // MARK: - Silent Push Notification Handler
    /// Called when a silent push notification is received (content-available: 1)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔕 [NotificationDelegate] Received remote notification (possibly silent)")
        print("🔕 [NotificationDelegate] Payload: \(userInfo)")

        // Check if this is a silent push (no alert, just data)
        if let aps = userInfo["aps"] as? [String: Any],
           aps["alert"] == nil,
           aps["content-available"] as? Int == 1 {
            // This is a silent push - handle it
            print("🔕 [NotificationDelegate] Silent push detected, handling...")
            Task { @MainActor in
                SilentPushHandler.shared.handleSilentPush(userInfo: userInfo, completion: completionHandler)
            }
        } else {
            // Regular push notification
            print("🔔 [NotificationDelegate] Regular push notification")
            completionHandler(.noData)
        }
    }
}
