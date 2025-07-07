import SwiftUI
import WidgetKit

struct MeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var timerViewModel: TimerViewModel
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var darkModeEnabled = true
    @State private var unitsMetric = true
    @State private var showingDailySummaryAlert = false
    @State private var showingResetOnboardingAlert = false
    
    var body: some View {
        NavigationView {
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
                            Text(notificationManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
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
                    
                    NavigationLink(destination: NotificationSettingsView()) {
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
                    Toggle("Dark Mode", isOn: $darkModeEnabled)
                        .onChange(of: darkModeEnabled) { oldValue, newValue in
                            // Handle dark mode toggle
                        }
                    
                    Toggle("Metric Units", isOn: $unitsMetric)
                        .onChange(of: unitsMetric) { oldValue, newValue in
                            // Handle units toggle
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
                
                // Developer Section (for testing)
                Section {
                    Button("Reset Onboarding") {
                        showingResetOnboardingAlert = true
                    }
                    .foregroundColor(.red)
                    
                    // Widget Debug Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Widget Debug")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Button("Test Widget Data") {
                            timerViewModel.testWidgetData()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .font(.caption)
                        
                        Button("Force Widget Refresh") {
                            timerViewModel.forceWidgetRefresh()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .font(.caption)
                        
                        Button("Manual Widget Test") {
                            // Force a manual widget refresh by updating data and reloading
                            timerViewModel.currentUVIndex = 9
                            timerViewModel.timeToBurn = 90
                            timerViewModel.isTimerRunning = true
                            timerViewModel.updateSharedData()
                            WidgetCenter.shared.reloadAllTimelines()
                            print("TimerViewModel: Manual widget test triggered")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
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
        }
    }
} 