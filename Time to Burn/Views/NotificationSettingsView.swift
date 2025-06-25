import SwiftUI

struct NotificationSettingsView: View {
    @State private var uvThreshold = 6
    @State private var isHighUVAlertsEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("UV Alert Settings")) {
                    Toggle("Enable High UV Alerts", isOn: $isHighUVAlertsEnabled)
                    
                    if isHighUVAlertsEnabled {
                        VStack(alignment: .leading) {
                            Text("UV Index Threshold")
                                .font(.headline)
                            Text("Get notified when UV index reaches this level or higher")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("UV Threshold", selection: $uvThreshold) {
                                Text("3 - Moderate").tag(3)
                                Text("6 - High").tag(6)
                                Text("8 - Very High").tag(8)
                                Text("11 - Extreme").tag(11)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
                
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Load saved settings
            self.uvThreshold = UserDefaults.standard.integer(forKey: "uvAlertThreshold")
            if self.uvThreshold == 0 {
                self.uvThreshold = 6
            }
            self.isHighUVAlertsEnabled = UserDefaults.standard.bool(forKey: "highUVAlertsEnabled")
        }
        .onChange(of: uvThreshold) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "uvAlertThreshold")
        }
        .onChange(of: isHighUVAlertsEnabled) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "highUVAlertsEnabled")
        }
    }
}

struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
    }
} 