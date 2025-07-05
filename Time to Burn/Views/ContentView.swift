import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // UV Tab - Home page with UV chart and data
            UVHomeView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "sun.max.fill")
                    Text("UV")
                }
                .tag(0)
            
            // Forecast Tab - Today's UV chart and tomorrow's estimate
            ForecastView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Forecast")
                }
                .tag(1)
            
            // Timer Tab - Dynamic sun exposure timer
            DynamicTimerView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .environmentObject(timerViewModel)
                .tabItem {
                    Image(systemName: "timer")
                    Text("Timer")
                }
                .tag(2)
            
            // Map Tab - Location search
            MapView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
                .tag(3)
            
            // Me Tab - User settings
            MeView()
                .environmentObject(locationManager)
                .environmentObject(weatherViewModel)
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Me")
                }
                .tag(4)
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
        .onReceive(NotificationCenter.default.publisher(for: .openTimerTab)) { _ in
            selectedTab = 2 // Switch to Timer tab
        }
        .onOpenURL { url in
            handleDeepLink(url: url)
        }
    }
    
    private func handleDeepLink(url: URL) {
        switch url.scheme {
        case "timetoburn":
            switch url.host {
            case "apply-sunscreen":
                timerViewModel.applySunscreenFromLiveActivity()
            case "open-timer":
                timerViewModel.openTimerTab()
            default:
                break
            }
        default:
            break
        }
    }
} 