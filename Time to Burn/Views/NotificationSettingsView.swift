import SwiftUI

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    @State private var showingPermissionAlert = false
    @State private var showingTestNotification = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("High UV Alerts")) {
                    Toggle("Enable High UV Alerts", isOn: $notificationService.isHighUVAlertsEnabled)
                    
                    if notificationService.isHighUVAlertsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alert Threshold: \(notificationService.uvAlertThreshold)")
                                .font(.subheadline)
                            
                            Slider(value: Binding(
                                get: { Double(notificationService.uvAlertThreshold) },
                                set: { newValue in
                                    notificationService.uvAlertThreshold = Int(newValue.rounded())
                                }
                            ), in: 1...12, step: 1)
                        }
                    }
                }
                
                Section(header: Text("Daily Updates")) {
                    Toggle("Enable Daily Updates", isOn: $notificationService.isDailyUpdatesEnabled)
                }
                
                Section(header: Text("Location Changes")) {
                    Toggle("Enable Location Change Notifications", isOn: $notificationService.isLocationChangesEnabled)
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
        }
    }
    
    // ... rest of existing code ...
} 