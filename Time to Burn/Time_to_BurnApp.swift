//
//  Time_to_BurnApp.swift
//  Time to Burn
//
//  Created by Steven Taylor on 6/12/25.
//

import SwiftUI
import WeatherKit
import UserNotifications

@main
struct Time_to_BurnApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherViewModel: WeatherViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var timerViewModel = TimerViewModel()
    @StateObject private var settingsManager = SettingsManager.shared
    
    init() {
        print("🚀 [App] 🚀 App initializing...")
        
        let locationManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locationManager)
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(locationManager: locationManager))
        _notificationManager = StateObject(wrappedValue: NotificationManager.shared)
        _onboardingManager = StateObject(wrappedValue: OnboardingManager.shared)
        
        // Configure UnitConverter with SettingsManager
        UnitConverter.shared.configure(with: SettingsManager.shared)
        
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        print("🚀 [App] ✅ App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingManager.isOnboardingComplete {
                ContentView()
                    .environmentObject(locationManager)
                    .environmentObject(weatherViewModel)
                    .environmentObject(notificationManager)
                    .environmentObject(timerViewModel)
                    .environmentObject(settingsManager)
                    .onAppear {
                        // Set dependencies for TimerViewModel
                        timerViewModel.setDependencies(locationManager: locationManager, weatherViewModel: weatherViewModel)
                        
                        // Request notification permissions on app start
                        Task {
                            await notificationManager.forceRequestNotificationPermission()
                            
                            // Schedule daily weather refresh after permissions are granted
                            if notificationManager.isAuthorized {
                                weatherViewModel.scheduleDailyWeatherRefresh()
                            }
                        }
                        
                        // Weather data will be fetched automatically when location is available
                        print("🚀 [App] ✅ App appeared, waiting for location and weather data...")
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        // Check for daily sunscreen reset and refresh data when app becomes active
                        print("🚀 [App] 🔄 App became active, checking daily reset and refreshing data...")
                        timerViewModel.handleAppBecameActive()
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
            }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        print("🔔 [NotificationDelegate] Notification received: \(identifier), action: \(actionIdentifier)")
        
        // Handle daily weather refresh notification
        if identifier == "daily_weather_refresh" || actionIdentifier == "REFRESH_WEATHER" {
            print("🔔 [NotificationDelegate] 🌤️ Daily weather refresh triggered")
            
            // Post notification to trigger weather refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
            }
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive notification: UNNotification) {
        let identifier = notification.request.identifier
        
        // Handle daily weather refresh notification when app is in background
        if identifier == "daily_weather_refresh" {
            print("🔔 [NotificationDelegate] 🌤️ Daily weather refresh received in background")
            
            // Post notification to trigger weather refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("dailyWeatherRefresh"), object: nil)
            }
        }
    }
}
