import SwiftUI
import WeatherKit

struct ContentView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var showingNotifications = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
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
                        
                        // Advice Card
                        if let uvData = weatherViewModel.currentUVData {
                            AdviceCard(advice: uvData.advice)
                        }
                        
                        // Time to Burn Card
                        if let uvData = weatherViewModel.currentUVData {
                            TimeToBurnCard(timeToBurn: uvData.timeToBurn)
                        }
                        
                        Button(action: {
                            Task {
                                locationManager.requestLocation()
                                await weatherViewModel.refreshData()
                            }
                        }) {
                            Label("Update Location", systemImage: "location.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top)
                        
                        if let lastUpdate = weatherViewModel.lastUpdateTime {
                            Text("Last updated: \(timeAgoString(from: lastUpdate))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
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
                NotificationRow(
                    title: "High UV Alerts",
                    description: "Get notified when UV index is high",
                    isEnabled: $notificationService.isHighUVAlertsEnabled
                )
                
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
            
            Spacer()
        }
        .padding()
    }
    
    private func updateNotificationPreferences() {
        notificationService.updateNotificationPreferences(
            highUVAlerts: notificationService.isHighUVAlertsEnabled,
            dailyUpdates: notificationService.isDailyUpdatesEnabled,
            locationChanges: notificationService.isLocationChangesEnabled
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
                
                Text(uvIndexText(uvData.uvIndex))
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(uvIndexColor(uvData.uvIndex))
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
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
    
    private func uvIndexText(_ index: Int) -> String {
        if index == 0 {
            return "No chance of sunburn"
        } else {
            return "\(index)"
        }
    }
}

struct AdviceCard: View {
    let advice: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Protection Advice")
                .font(.headline)
            
            Text(advice)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

struct TimeToBurnCard: View {
    let timeToBurn: Int
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Time to Burn")
                .font(.headline)
            
            Text("\(timeToBurn) minutes")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.red)
            
            Text("of unprotected exposure")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
        .environmentObject(WeatherViewModel())
}

extension ContentView {
    func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
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