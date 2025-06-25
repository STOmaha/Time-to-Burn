//
//  Time_to_BurnApp.swift
//  Time to Burn
//
//  Created by Steven Taylor on 6/12/25.
//

import SwiftUI
import WeatherKit

@main
struct Time_to_BurnApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherViewModel: WeatherViewModel
    
    init() {
        let locationManager = LocationManager()
        _locationManager = StateObject(wrappedValue: locationManager)
        _weatherViewModel = StateObject(wrappedValue: WeatherViewModel(locationManager: locationManager))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
        }
    }
}
