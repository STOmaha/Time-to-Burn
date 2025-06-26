import SwiftUI

struct MeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = true
    @State private var unitsMetric = true
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time to Burn User")
                                .font(.headline)
                                .fontWeight(.medium)
                            Text("UV Protection Expert")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                // Settings Section
                Section("Settings") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Notifications")
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Dark Mode")
                        Spacer()
                        Toggle("", isOn: $darkModeEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("Units")
                        Spacer()
                        Picker("Units", selection: $unitsMetric) {
                            Text("Metric").tag(true)
                            Text("Imperial").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                }
                
                // Location Section
                Section("Location") {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(locationManager.locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        // TODO: Implement location refresh
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Refresh Location")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // App Info Section
                Section("App Info") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)
                        Text("Help & Support")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 24)
                        Text("Rate App")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
        }
    }
} 