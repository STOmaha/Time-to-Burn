import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    
    var body: some View {
        TabView {
            // UV Tab - Home page with UV chart and data
            UVHomeView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "sun.max.fill")
                    Text("UV")
                }
            
            // Clock Tab - Astronomical clock
            AstronomicalClockTabView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text("Clock")
                }
            
            // Forecast Tab - Today's UV chart and tomorrow's estimate
            ForecastView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Forecast")
                }
            
            // Map Tab - Location search
            MapView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
            
            // Me Tab - User settings
            MeView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Me")
                }
        }
        .accentColor(.orange) // UV-themed accent color
    }
} 