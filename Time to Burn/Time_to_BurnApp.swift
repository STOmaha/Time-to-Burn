//
//  Time_to_BurnApp.swift
//  Time to Burn
//
//  Created by Steven Taylor on 6/12/25.
//

import SwiftUI
import WeatherKit
// import UserNotifications
// TODO: Re-enable Firebase imports after adding Firebase SDK
// import Firebase
// import FirebaseMessaging

@main
struct Time_to_BurnApp: App {
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var weatherViewModel: WeatherViewModel
    // @StateObject private var notificationManager = NotificationManager.shared
    // @StateObject private var onboardingManager = OnboardingManager.shared
    // @StateObject private var timerViewModel = TimerViewModel()
    // @StateObject private var settingsManager = SettingsManager.shared
    // @StateObject private var authenticationManager = AuthenticationManager.shared
    // @StateObject private var pushNotificationService = PushNotificationService.shared
    
    init() {
        print("🚀 [App] 🚀 App initializing...")
        
        // TODO: Re-enable Firebase initialization after adding Firebase SDK
        // Initialize Firebase
        // FirebaseApp.configure()
        // print("🚀 [App] 🔥 Firebase initialized")
        
        // Use shared LocationManager instance
        let locationManager = LocationManager.shared
        _locationManager = StateObject(wrappedValue: locationManager)
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(locationManager: locationManager))
        // _notificationManager = StateObject(wrappedValue: NotificationManager.shared)
        // _onboardingManager = StateObject(wrappedValue: OnboardingManager.shared)
        // _authenticationManager = StateObject(wrappedValue: AuthenticationManager.shared)
        // _pushNotificationService = StateObject(wrappedValue: PushNotificationService.shared)
        
        // Configure UnitConverter with SettingsManager
        // UnitConverter.shared.configure(with: SettingsManager.shared)
        
        // Setup notification delegate
        // UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Setup app delegate for push notifications
        // if UIApplication.shared.delegate is NotificationDelegate {
        //     // Already set
        // } else {
        //     UIApplication.shared.delegate = NotificationDelegate.shared
        // }
        
        print("🚀 [App] ✅ App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            // if onboardingManager.isOnboardingComplete {
            //     if authenticationManager.isAuthenticated {
                    ContentView()
                        .environmentObject(locationManager)
                        .environmentObject(weatherViewModel)
                        // .environmentObject(notificationManager)
                        // .environmentObject(timerViewModel)
                        // .environmentObject(settingsManager)
                        // .environmentObject(authenticationManager)
                        // .environmentObject(pushNotificationService)
                        .onAppear {
                            // Set dependencies for TimerViewModel
                            // timerViewModel.setDependencies(locationManager: locationManager, weatherViewModel: weatherViewModel)
                            
                            // Request notification permissions on app start
                            // Task {
                            //     await notificationManager.forceRequestNotificationPermission()
                            //     
                            //     // Schedule daily weather refresh after permissions are granted
                            //     if notificationManager.isAuthorized {
                            //         weatherViewModel.scheduleDailyWeatherRefresh()
                            //     }
                            // }
                            
                            // Weather data will be fetched automatically when location is available
                            print("🚀 [App] ✅ App appeared, waiting for location and weather data...")
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            // Check for daily sunscreen reset and refresh data when app becomes active
                            print("🚀 [App] 🔄 App became active, checking daily reset and refreshing data...")
                            // timerViewModel.handleAppBecameActive()
                            Task {
                                await weatherViewModel.refreshData()
                            }
                        }
                        // .onReceive(NotificationCenter.default.publisher(for: Notification.Name("applySunscreenFromLiveActivity"))) { _ in
                        //     timerViewModel.applySunscreenFromLiveActivity()
                        // }

                // } else {
                //     AuthenticationView()
                //         .environmentObject(authenticationManager)
                // }
            // } else {
            //     OnboardingView()
            //         .environmentObject(locationManager)
            //         .environmentObject(weatherViewModel)
            //         .environmentObject(notificationManager)
            //         .environmentObject(settingsManager)
            // }
        }
    }
}

// MARK: - Notification Delegate
// TODO: Re-enable MessagingDelegate after adding Firebase SDK
// class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate /*, MessagingDelegate */ {
//     static let shared = NotificationDelegate()
//     
//     private let pushNotificationService = PushNotificationService.shared
//     
//     func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//         // Show notification even when app is in foreground
//         completionHandler([.banner, .sound, .badge])
//     }
//     
//     func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//         let identifier = response.notification.request.identifier
//         let actionIdentifier = response.actionIdentifier
//         let categoryIdentifier = response.notification.request.content.categoryIdentifier
//         
//         print("🔔 [NotificationDelegate] Notification received: \(identifier), action: \(actionIdentifier), category: \(categoryIdentifier)")
//         
//         // Handle daily weather refresh notification
//         if identifier == "daily_weather_refresh" || actionIdentifier == "REFRESH_WEATHER" {
//             print("🔔 [NotificationDelegate] 🌤️ Daily weather refresh triggered")
//             
//             // Post notification to trigger weather refresh
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
//             }
//         }
//         
//         // Handle push notification types
//         if let notificationType = PushNotificationService.NotificationType(rawValue: categoryIdentifier) {
//             handlePushNotification(notificationType, actionIdentifier: actionIdentifier)
//         }
//         
//         completionHandler()
//     }
//     
//     private func handlePushNotification(_ type: PushNotificationService.NotificationType, actionIdentifier: String) {
//         print("🔔 [NotificationDelegate] 📱 Handling push notification: \(type.title)")
//         
//         switch type {
//         case .uvAlert:
//             // Handle UV alert - could open UV tab
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("openUVTab"), object: nil)
//             }
//             
//         case .timerReminder:
//             // Handle timer reminder - could open timer tab
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("openTimerTab"), object: nil)
//             }
//             
//         case .dailySummary:
//             // Handle daily summary - could open summary view
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("openDailySummary"), object: nil)
//             }
//             
//         case .sunscreenReminder:
//             // Handle sunscreen reminder
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("sunscreenReminder"), object: nil)
//             }
//             
//         case .weatherUpdate:
//             // Handle weather update - could refresh weather data
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("refreshWeatherData"), object: nil)
//             }
//         }
//     }
//     
//     func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive notification: UNNotification) {
//         let identifier = notification.request.identifier
//         
//         // Handle daily weather refresh notification when app is in background
//         if identifier == "daily_weather_refresh" {
//             print("🔔 [NotificationDelegate] 🌤️ Daily weather refresh received in background")
//             
//             // Post notification to trigger weather refresh
//             DispatchQueue.main.async {
//                 NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
//             }
//         }
//     }
//     
//     // MARK: - Firebase Messaging Delegate
//     // TODO: Re-enable Firebase messaging delegate after adding Firebase SDK
//     
//     /*
//     func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
//         print("🔔 [NotificationDelegate] 🔥 FCM token received: \(fcmToken ?? "nil")")
//         
//         // Store FCM token locally (Supabase removed)
//         if let token = fcmToken {
//             Task {
//                 // TODO: Re-enable FCM token handling after adding Firebase SDK
//                 // await pushNotificationService.handleFCMToken(token)
//             }
//         }
//     }
//     */
//     
//     // TODO: Re-enable Firebase messaging delegate after adding Firebase SDK
//     // func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
//     //     print("🔔 [NotificationDelegate] 🔥 FCM token received: \(fcmToken ?? "nil")")
//     //     
//     //     // Store FCM token locally (Supabase removed)
//     //     if let token = fcmToken {
//     //         Task {
//     //             await pushNotificationService.handleFCMToken(token)
//     //         }
//     //     }
//     // }
//     
//     // MARK: - UIApplicationDelegate Methods for Push Notifications
//     
//     func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//         print("🔔 [NotificationDelegate] 📱 Device token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
//         
//         // TODO: Re-enable Firebase APNs token setting after adding Firebase SDK
//         // Set the APNs token for Firebase
//         // Messaging.messaging().apnsToken = deviceToken
//     }
//     
//     func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
//         print("🔔 [NotificationDelegate] ❌ Failed to register for remote notifications: \(error)")
//         pushNotificationService.handleRegistrationError(error)
//     }
// }
