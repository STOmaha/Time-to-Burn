import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @StateObject private var timerViewModel = TimerViewModel()
    
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
            
            // Forecast Tab - Today's UV chart and tomorrow's estimate
            ForecastView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Forecast")
                }
            
            // Timer Tab - Dynamic sun exposure timer
            DynamicTimerView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .environmentObject(timerViewModel)
                .tabItem {
                    Image(systemName: "timer")
                    Text("Timer")
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
        .onAppear {
            // Ensure TabBar has proper contrast
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            
            // Sync timer with current UV data when view appears
            if let currentUV = weatherViewModel.currentUVData?.uvIndex {
                timerViewModel.syncWithCurrentUVData(uvIndex: currentUV)
            }
        }
        .onChange(of: weatherViewModel.currentUVData?.uvIndex) { _, newUVIndex in
            // Update timer when UV index changes
            if let uvIndex = newUVIndex {
                timerViewModel.updateUVIndex(uvIndex)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh widget when app becomes active
            timerViewModel.refreshWidget()
            weatherViewModel.appBecameActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            weatherViewModel.appWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            weatherViewModel.appDidEnterBackground()
        }
    }
} 