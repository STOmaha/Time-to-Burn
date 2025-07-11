import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingPermissionAlert = false
    @State private var dailyWeatherRefreshEnabled = false
    @State private var showingDailyRefreshInfo = false
    let weatherViewModel: WeatherViewModel?
    
    init(weatherViewModel: WeatherViewModel? = nil) {
        self.weatherViewModel = weatherViewModel
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Notification Permission Section
                Section {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notificationManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                                .font(.headline)
                            Text(notificationManager.isAuthorized ? "You'll receive alerts for sun protection" : "Enable notifications to get sun protection alerts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                // Sunscreen Reminders Section
                Section(header: Text("Sunscreen Reminders")) {
                    Toggle("Sunscreen Reapply Alerts", isOn: $notificationManager.notificationSettings.sunscreenRemindersEnabled)
                        .disabled(!notificationManager.isAuthorized)
                    
                    if notificationManager.notificationSettings.sunscreenRemindersEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                Text("Reminder Interval")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text("You'll be reminded to reapply sunscreen every 2 hours after applying it in the Timer tab.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // Exposure Warnings Section
                Section(header: Text("Sun Exposure Warnings")) {
                    Toggle("Exposure Limit Alerts", isOn: $notificationManager.notificationSettings.exposureWarningsEnabled)
                        .disabled(!notificationManager.isAuthorized)
                    
                    if notificationManager.notificationSettings.exposureWarningsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Warning Levels")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Approaching Limit (80% of safe time)")
                                        .font(.caption)
                                }
                                HStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                    Text("Exposure Exceeded (100% of safe time)")
                                        .font(.caption)
                                }
                            }
                            
                            Text("You'll be alerted when approaching or exceeding your safe sun exposure time based on current UV levels.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // UV Threshold Alerts Section
                Section(header: Text("UV Index Alerts")) {
                    Toggle("High UV Alerts", isOn: $notificationManager.notificationSettings.uvThresholdAlertsEnabled)
                        .disabled(!notificationManager.isAuthorized)
                    
                    if notificationManager.notificationSettings.uvThresholdAlertsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("UV Index Threshold")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Get notified when UV index reaches this level or higher")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("UV Threshold", selection: $notificationManager.notificationSettings.uvThreshold) {
                                Text("3 - Moderate").tag(3)
                                Text("6 - High").tag(6)
                                Text("8 - Very High").tag(8)
                                Text("11 - Extreme").tag(11)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("Current threshold: UV \(notificationManager.notificationSettings.uvThreshold)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Daily Weather Refresh Section
                Section(header: Text("Weather Updates")) {
                    Toggle("Daily Weather Refresh", isOn: $dailyWeatherRefreshEnabled)
                        .disabled(!notificationManager.isAuthorized)
                        .onChange(of: dailyWeatherRefreshEnabled) { _, newValue in
                            if newValue {
                                weatherViewModel?.scheduleDailyWeatherRefresh()
                            } else {
                                weatherViewModel?.cancelDailyWeatherRefresh()
                            }
                        }
                    
                    if dailyWeatherRefreshEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.orange)
                                Text("Refresh Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text("Automatically update UV data at 8:00 AM daily")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Learn More") {
                                showingDailyRefreshInfo = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // Daily Summary Section
                Section(header: Text("Daily Summary")) {
                    Toggle("Daily Exposure Summary", isOn: $notificationManager.notificationSettings.dailySummaryEnabled)
                        .disabled(!notificationManager.isAuthorized)
                    
                    if notificationManager.notificationSettings.dailySummaryEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.green)
                                Text("Summary Time")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text("Receive a daily summary of your sun exposure at 8:00 PM")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // About Section
                Section(header: Text("About")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time to Burn")
                            .font(.headline)
                        Text("Monitor UV exposure and get alerts when conditions are dangerous for your skin.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: notificationManager.notificationSettings) { _, newSettings in
                notificationManager.updateSettings(newSettings)
            }
            .onAppear {
                // Check if daily weather refresh is scheduled
                Task {
                    if let weatherViewModel = weatherViewModel {
                        dailyWeatherRefreshEnabled = await weatherViewModel.isDailyWeatherRefreshScheduled()
                    }
                }
            }
            .alert("Enable Notifications", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To receive sun protection alerts, please enable notifications in Settings.")
            }
            .alert("Daily Weather Refresh", isPresented: $showingDailyRefreshInfo) {
                Button("OK") { }
            } message: {
                Text("This feature automatically refreshes your UV data every morning at 8:00 AM. It uses a local notification to trigger the refresh, ensuring you always have the most current weather information for your sun exposure planning.")
            }
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            let granted = await notificationManager.requestNotificationPermission()
            if !granted {
                await MainActor.run {
                    showingPermissionAlert = true
                }
            }
        }
    }
    

}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView(weatherViewModel: nil)
    }
} 