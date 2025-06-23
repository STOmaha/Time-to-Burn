import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notificationService: NotificationService
    @State private var showingPermissionAlert = false
    @State private var uvThreshold: Int
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
                        VStack(alignment: .leading) {
                            Text("Alert Threshold: \(uvThreshold)")
                                .font(.subheadline)
                            Slider(value: uvThresholdBinding, in: 1...12, step: 1)
                        }
                        .padding(.vertical, 4)
                    }
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
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .environmentObject(NotificationService.shared)
    }
} 