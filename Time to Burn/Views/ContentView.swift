import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        MainContentView()
            .environmentObject(locationManager)
            .environmentObject(weatherViewModel)
    }
} 