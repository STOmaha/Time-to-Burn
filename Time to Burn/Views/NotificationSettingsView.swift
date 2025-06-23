import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationService: NotificationService
    @State private var showingPermissionAlert = false
    @State private var showingTestNotification = false
    @State private var uvThreshold: Int
    @State private var showingAlert = false
    @State private var isDailySummaryEnabled: Bool
    
    init() {
        _uvThreshold = State(initialValue: NotificationService.shared.uvAlertThreshold)
        _isDailySummaryEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "isDailySummaryEnabled"))
    }
    
    // Custom binding to convert Int state to Double for the Slider
    private var uvThresholdBinding: Binding<Double> {
        Binding<Double>(
            get: {
                return Double(self.uvThreshold)
            },
            set: {
                self.uvThreshold = Int($0)
                notificationService.uvAlertThreshold = self.uvThreshold
            }
        )
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("High UV Alerts")) {
                    Toggle("Enable High UV Alerts", isOn: $notificationService.isHighUVAlertsEnabled)
                    
                    if notificationService.isHighUVAlertsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alert Threshold: \(uvThreshold)")
                                .font(.subheadline)
                            
                            Slider(value: uvThresholdBinding, in: 1...12, step: 1)
                        }
                    }
                }
                
                Section(header: Text("Daily Updates")) {
                    Toggle("Enable Daily Updates", isOn: $notificationService.isDailyUpdatesEnabled)
                }
                
                Section(header: Text("Location Changes")) {
                    Toggle("Enable Location Change Notifications", isOn: $notificationService.isLocationChangesEnabled)
                }
                
                Section(header: Text("Daily Summary")) {
                    Toggle("8 AM Daily Forecast", isOn: $isDailySummaryEnabled)
                        .onChange(of: isDailySummaryEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "isDailySummaryEnabled")
                            if newValue {
                                BackgroundService.shared.scheduleAppRefresh()
                            } else {
                                BackgroundService.shared.cancel()
                            }
                        }
                    Text("Receive a notification every morning with a summary of the day's UV forecast and times to avoid sun exposure.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: {
                        notificationService.testHighUVNotification()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.blue)
                            Text("Test High UV Notification")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Button(action: {
                        notificationService.triggerBackgroundUVCheck()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.green)
                            Text("Trigger Background UV Check")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Test Notifications")
                } footer: {
                    Text("Tap to test notifications and background checks")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings", role: .none) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable notifications in Settings to receive UV alerts and updates.")
            }
            .onAppear {
                self.uvThreshold = notificationService.uvAlertThreshold
            }
        }
    }
    
    // ... rest of existing code ...
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .environmentObject(NotificationService.shared)
    }
} 