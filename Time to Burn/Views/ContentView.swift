import SwiftUI
import WeatherKit

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var showingNotifications = false
    
    var body: some View {
        ZStack {
            // Dynamic background gradient based on UV Index
            LinearGradient(
                gradient: Gradient(colors: [darkerUVColor, darkerUVColor.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if weatherViewModel.isLoading {
                VStack(spacing: 20) {
                    ProgressView("Loading UV data...")
                        .scaleEffect(1.5)
                    Text("Please ensure location services are enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = weatherViewModel.error {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error loading UV data")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(error.localizedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        Task {
                            locationManager.requestLocation()
                            await weatherViewModel.refreshData()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        // Location and UV Index Card
                        UVIndexCard(
                            location: locationManager.locationName,
                            uvData: weatherViewModel.currentUVData
                        )
                        if let lastUpdate = weatherViewModel.lastUpdateTime {
                            TimelineView(.periodic(from: lastUpdate, by: 1)) { context in
                                Text("Last updated: \(timeAgoString(from: lastUpdate, to: context.date))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    locationManager.requestLocation()
                    await weatherViewModel.refreshData()
                }
            }
            
            // Notification Bell Button
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        showingNotifications = true
                    }) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(radius: 3)
                    }
                    .padding(.leading, 20)
                    .padding(.bottom, 20)
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationCard()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task {
            print("ContentView: Initial task started")
            locationManager.requestLocation()
            if let location = locationManager.location {
                print("ContentView: Location available, fetching UV data")
                await weatherViewModel.fetchUVData(for: location)
            } else {
                print("ContentView: No location available")
            }
        }
        .onChange(of: locationManager.location) { oldValue, newValue in
            print("ContentView: Location changed")
            if let location = newValue {
                Task {
                    await weatherViewModel.fetchUVData(for: location)
                }
            }
        }
    }
    
    // Add computed property for dynamic background color
    private var darkerUVColor: Color {
        guard let uvIndex = weatherViewModel.currentUVData?.uvIndex else {
            return Color.blue.opacity(0.7)
        }
        switch uvIndex {
        case 0: return Color.blue.darken()
        case 1...2: return Color.green.darken()
        case 3...5: return Color.yellow.darken()
        case 6...7: return Color.orange.darken()
        case 8...10: return Color.red.darken()
        default: return Color.purple.darken()
        }
    }
}

struct NotificationCard: View {
    @EnvironmentObject private var notificationService: NotificationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Notifications")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    NotificationRow(
                        title: "High UV Alerts",
                        description: "Get notified when UV index is high",
                        isEnabled: $notificationService.isHighUVAlertsEnabled
                    )
                    if notificationService.isHighUVAlertsEnabled {
                        HStack {
                            Text("Alert Threshold: ")
                                .font(.subheadline)
                            Slider(value: Binding(
                                get: { Double(notificationService.uvAlertThreshold) },
                                set: { newValue in
                                    let intValue = Int(newValue.rounded())
                                    notificationService.uvAlertThreshold = intValue
                                    notificationService.updateNotificationPreferences(
                                        highUVAlerts: notificationService.isHighUVAlertsEnabled,
                                        dailyUpdates: notificationService.isDailyUpdatesEnabled,
                                        locationChanges: notificationService.isLocationChangesEnabled,
                                        uvAlertThreshold: intValue
                                    )
                                }
                            ), in: 1...11, step: 1)
                            .frame(maxWidth: 150)
                            Text("\(notificationService.uvAlertThreshold)")
                                .font(.subheadline)
                                .frame(width: 28)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                NotificationRow(
                    title: "Daily Updates",
                    description: "Receive daily UV index updates",
                    isEnabled: $notificationService.isDailyUpdatesEnabled
                )
                NotificationRow(
                    title: "Location Changes",
                    description: "Get notified when you enter a new area",
                    isEnabled: $notificationService.isLocationChangesEnabled
                )
            }
            .onChange(of: notificationService.isHighUVAlertsEnabled) { oldValue, newValue in
                updateNotificationPreferences()
            }
            .onChange(of: notificationService.isDailyUpdatesEnabled) { oldValue, newValue in
                updateNotificationPreferences()
            }
            .onChange(of: notificationService.isLocationChangesEnabled) { oldValue, newValue in
                updateNotificationPreferences()
            }
            
            // Debug/Test Button
            Button(action: {
                notificationService.testHighUVNotification()
            }) {
                Label("Test High UV Notification", systemImage: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
            .accessibilityIdentifier("TestHighUVNotificationButton")
            
            Spacer()
        }
        .padding()
    }
    
    private func updateNotificationPreferences() {
        notificationService.updateNotificationPreferences(
            highUVAlerts: notificationService.isHighUVAlertsEnabled,
            dailyUpdates: notificationService.isDailyUpdatesEnabled,
            locationChanges: notificationService.isLocationChangesEnabled,
            uvAlertThreshold: notificationService.uvAlertThreshold
        )
    }
}

struct NotificationRow: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct UVIndexCard: View {
    let location: String
    let uvData: UVData?
    
    var body: some View {
        VStack(spacing: 15) {
            Text(location)
                .font(.title2)
                .fontWeight(.medium)
            
            if let uvData = uvData {
                Text("UV Index")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ZStack {
                    Text(uvIndexDisplay(uvData.uvIndex))
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.black)
                        .opacity(0.25)
                        .overlay(
                            Text(uvIndexDisplay(uvData.uvIndex))
                                .font(.system(size: 72, weight: .bold))
                                .foregroundColor(uvIndexColor(uvData.uvIndex))
                                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                        )
                }
                
                Text("\(uvData.timeToBurn) minutes to burn")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                Divider()
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Protection Advice")
                        .font(.headline)
                    Text(uvData.advice)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
    
    private func uvIndexColor(_ index: Int) -> Color {
        switch index {
        case 0: return .blue
        case 1...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    private func uvIndexDisplay(_ index: Int) -> String {
        if index == 0 {
            return UVData.getAdvice(uvIndex: 0)
        } else {
            return "\(index)"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(WeatherViewModel())
}

extension ContentView {
    func timeAgoString(from date: Date, to now: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour], from: date, to: now)
        if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute {
            if minute == 0 {
                return "Just now"
            }
            return "\(minute)m ago"
        }
        return "Just now"
    }
}

// Add Color extension for darken
extension Color {
    func darken(amount: Double = 0.5) -> Color {
        return self.opacity(1.0 - amount)
    }
} 