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
        // Initialize WeatherViewModel with the same NotificationService instance
        let notificationService = NotificationService.shared
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(notificationService: notificationService))
        
        // Register background task
        notificationService.registerBackgroundTask()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(notificationService)
                .environmentObject(weatherViewModel)
        }
    }
}
