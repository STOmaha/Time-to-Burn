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
    private var notificationService = NotificationService.shared
    @StateObject private var weatherViewModel: WeatherViewModel
    
    init() {
        // Register background task handlers BEFORE app finishes launching
        NotificationService.shared.registerBackgroundTaskHandlers()
        
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(notificationService: NotificationService.shared))
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
