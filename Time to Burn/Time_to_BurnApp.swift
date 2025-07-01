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
    
    init() {
        let locationManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locationManager)
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(locationManager: locationManager))
        _notificationManager = StateObject(wrappedValue: NotificationManager.shared)
        _onboardingManager = StateObject(wrappedValue: OnboardingManager.shared)
        
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingManager.isOnboardingComplete {
                ContentView()
                    .environmentObject(locationManager)
                    .environmentObject(weatherViewModel)
                    .environmentObject(notificationManager)
                    .onAppear {
                        // Fetch initial UV data when app appears
                        Task {
                            await weatherViewModel.refreshData()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                        // Refresh data when app becomes active
                        Task {
                            await weatherViewModel.refreshData()
                        }
                    }
            } else {
                OnboardingView()
                    .environmentObject(locationManager)
                    .environmentObject(weatherViewModel)
                    .environmentObject(notificationManager)
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
        // Handle notification tap
        completionHandler()
    }
}
