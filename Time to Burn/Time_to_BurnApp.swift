//
//  Time_to_BurnApp.swift
//  Time to Burn
//
//  Created by Steven Taylor on 6/12/25.
//

import SwiftUI
import WeatherKit
import BackgroundTasks

@main
struct Time_to_BurnApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var weatherViewModel: WeatherViewModel
    
    init() {
        let notificationService = NotificationService()
        _notificationService = StateObject(wrappedValue: notificationService)
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(notificationService: notificationService))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationService)
                .environmentObject(weatherViewModel)
                .onAppear {
                    // Register the background task handler.
                    BackgroundService.shared.register()

                    // If the user has already enabled the daily summary,
                    // schedule it on app launch to ensure it's active.
                    if UserDefaults.standard.bool(forKey: "isDailySummaryEnabled") {
                        BackgroundService.shared.scheduleAppRefresh()
                    }
                }
        }
    }
}
