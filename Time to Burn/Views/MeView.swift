import SwiftUI
import WidgetKit
import AudioToolbox

struct MeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    @EnvironmentObject private var pushNotificationService: PushNotificationService
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var showingDailySummaryAlert = false
    @State private var showingResetOnboardingAlert = false
    @State private var showingSignOutAlert = false
    
    // MARK: - Homogeneous Background
    var homogeneousBackground: Color {
        let uvIndex = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uvIndex)
    }
    
    // Custom notification banner state
    @State private var showingNotificationBanner = false
    @State private var notificationBannerMessage = ""
    @State private var notificationBannerType: NotificationBannerType = .info
    
    enum NotificationBannerType {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Homogeneous UV background
                homogeneousBackground
                    .ignoresSafeArea()
                
                List {
                // Profile Section
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sun Safety User")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Stay protected, stay healthy")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Notifications Section
                Section("Notifications") {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notificationManager.isAuthorized ? "Local Notifications" : "Local Notifications Disabled")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(notificationManager.isAuthorized ? "You'll receive UV alerts and reminders" : "Enable to get UV alerts and reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                Task {
                                    await notificationManager.requestNotificationPermission()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Image(systemName: pushNotificationService.isRegistered ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundColor(pushNotificationService.isRegistered ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pushNotificationService.isRegistered ? "Push Notifications" : "Push Notifications")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(pushNotificationService.isRegistered ? "Server can send you real-time alerts" : "Enable for real-time server notifications")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !pushNotificationService.isRegistered {
                            Button("Enable") {
                                Task {
                                    await pushNotificationService.requestPermission()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if let deviceToken = pushNotificationService.deviceToken {
                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Device Token")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(String(deviceToken.prefix(20)) + "...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    NavigationLink(destination: NotificationSettingsView(weatherViewModel: weatherViewModel)) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.blue)
                            Text("Notification Settings")
                        }
                    }
                }
                
                // Location Section
                Section("Location") {
                    HStack {
                        let isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                        Image(systemName: isAuthorized ? "location.fill" : "location.slash.fill")
                            .foregroundColor(isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isAuthorized ? "Location Enabled" : "Location Disabled")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(isAuthorized ? "Getting UV data for your area" : "Enable to get local UV data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !isAuthorized {
                            Button("Enable") {
                                Task {
                                    locationManager.requestLocation()
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
                
                // App Settings Section
                Section("App Settings") {
                    Toggle("Dark Mode", isOn: $settingsManager.isDarkModeEnabled)
                    
                    Toggle("Metric Units", isOn: $settingsManager.isMetricUnits)
                    
                    Toggle("24-Hour Clock", isOn: $settingsManager.is24HourClock)
                    
                    HStack {
                        Text("Current Units")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(settingsManager.isMetricUnits ? "Metric (°C, km)" : "Imperial (°F, mi)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Current Time Format")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(settingsManager.is24HourClock ? "24-hour" : "12-hour")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // Daily Summary Section
                Section("Daily Summary") {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Summary")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Get a summary of your daily sun exposure")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Schedule") {
                            showingDailySummaryAlert = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                // Account Section
                Section("Account") {
                    if let userEmail = authenticationManager.userEmail {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text(userEmail)
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    
                    Button("Sign Out") {
                        showingSignOutAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // Developer Tools Section
                Section("Developer Tools") {
                    Button("Reset Onboarding") {
                        showingResetOnboardingAlert = true
                    }
                    .foregroundColor(.red)
                    
                    Button("Test Widget Data") {
                        timerViewModel.testWidgetDataFlow()
                        showNotificationBanner("Widget test data saved", type: .success)
                    }
                    .foregroundColor(.blue)
                    
                    Button("Test Daily Weather Refresh") {
                        weatherViewModel.testDailyWeatherRefresh()
                        showNotificationBanner("Daily weather refresh triggered", type: .success)
                    }
                    .foregroundColor(.orange)
                }
                }
            }
            .navigationTitle("Settings")
            .alert("Schedule Daily Summary", isPresented: $showingDailySummaryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Schedule") {
                    notificationManager.scheduleDailySummary(at: Date(), totalExposure: 0)
                }
            } message: {
                Text("You'll receive a daily summary of your sun exposure at 6 PM each day.")
            }
            .alert("Reset Onboarding", isPresented: $showingResetOnboardingAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    onboardingManager.startOnboarding()
                }
            } message: {
                Text("This will show the onboarding flow again. This is useful for testing.")
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authenticationManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your account.")
            }
        }
        .overlay(
            // Custom notification banner
            VStack {
                if showingNotificationBanner {
                    HStack {
                        Image(systemName: notificationBannerType.icon)
                            .foregroundColor(notificationBannerType.color)
                        Text(notificationBannerMessage)
                            .fontWeight(.medium)
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingNotificationBanner = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    .padding(.top, 50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
        )
    }
    

    
    // MARK: - Custom Notification Banner
    private func showNotificationBanner(_ message: String, type: NotificationBannerType) {
        notificationBannerMessage = message
        notificationBannerType = type
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingNotificationBanner = true
        }
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingNotificationBanner = false
            }
        }
    }
    

} 