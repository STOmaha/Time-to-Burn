// import SwiftUI

// struct NotificationSettingsView: View {
//     @EnvironmentObject private var notificationManager: NotificationManager
//     @EnvironmentObject private var settingsManager: SettingsManager
//     @Environment(\.dismiss) private var dismiss
    
//     @State private var uvAlertEnabled = true
//     @State private var timerReminderEnabled = true
//     @State private var dailySummaryEnabled = true
//     @State private var sunscreenReminderEnabled = true
//     @State private var showingPermissionAlert = false
    
//     var body: some View {
//         NavigationView {
//             List {
//                 Section(header: Text("UV Protection Alerts")) {
//                     Toggle("UV Index Alerts", isOn: $uvAlertEnabled)
//                         .onChange(of: uvAlertEnabled) { newValue in
//                             settingsManager.updateUVAlertEnabled(newValue)
//                             if newValue {
//                                 Task {
//                                     await notificationManager.requestPermission()
//                                 }
//                             }
//                         }
                    
//                     Toggle("Timer Reminders", isOn: $timerReminderEnabled)
//                         .onChange(of: timerReminderEnabled) { newValue in
//                             settingsManager.updateTimerReminderEnabled(newValue)
//                         }
//                 }
                
//                 Section(header: Text("Daily Summaries")) {
//                     Toggle("Daily UV Summary", isOn: $dailySummaryEnabled)
//                         .onChange(of: dailySummaryEnabled) { newValue in
//                             settingsManager.updateDailySummaryEnabled(newValue)
//                         }
//                 }
                
//                 Section(header: Text("Health Reminders")) {
//                     Toggle("Sunscreen Reminders", isOn: $sunscreenReminderEnabled)
//                         .onChange(of: sunscreenReminderEnabled) { newValue in
//                             settingsManager.updateSunscreenReminderEnabled(newValue)
//                         }
//                 }
                
//                 Section(header: Text("Notification Status")) {
//                     HStack {
//                         Text("Permission Status")
//                         Spacer()
//                         Text(notificationManager.isAuthorized ? "Granted" : "Denied")
//                             .foregroundColor(notificationManager.isAuthorized ? .green : .red)
//                     }
                    
//                     if !notificationManager.isAuthorized {
//                         Button("Request Permission") {
//                             Task {
//                                 await notificationManager.requestPermission()
//                             }
//                         }
//                         .foregroundColor(.blue)
//                     }
//                 }
                
//                 Section(header: Text("Test Notifications")) {
//                     Button("Test UV Alert") {
//                         Task {
//                             await notificationManager.sendTestUVAlert()
//                         }
//                     }
//                     .foregroundColor(.blue)
                    
//                     Button("Test Timer Reminder") {
//                         Task {
//                             await notificationManager.sendTestTimerReminder()
//                         }
//                     }
//                     .foregroundColor(.blue)
//                 }
//             }
//             .navigationTitle("Notifications")
//             .navigationBarTitleDisplayMode(.large)
//             .toolbar {
//                 ToolbarItem(placement: .navigationBarTrailing) {
//                     Button("Done") {
//                         dismiss()
//                     }
//                 }
//             }
//         }
//         .alert("Permission Required", isPresented: $showingPermissionAlert) {
//             Button("Settings") {
//                 if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
//                     UIApplication.shared.open(settingsUrl)
//                 }
//             }
//             Button("Cancel", role: .cancel) { }
//         } message: {
//             Text("Please enable notifications in Settings to receive UV alerts and reminders.")
//         }
//     }
// }

// #Preview {
//     NotificationSettingsView()
//         .environmentObject(NotificationManager.shared)
//         .environmentObject(SettingsManager.shared)
// } 