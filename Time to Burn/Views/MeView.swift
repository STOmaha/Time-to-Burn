// import SwiftUI
// import WidgetKit
// import AudioToolbox

// struct MeView: View {
//     @EnvironmentObject private var locationManager: LocationManager
//     @EnvironmentObject private var weatherViewModel: WeatherViewModel
//     @EnvironmentObject private var notificationManager: NotificationManager
//     @EnvironmentObject private var timerViewModel: TimerViewModel
//     @EnvironmentObject private var settingsManager: SettingsManager
//     @EnvironmentObject private var authenticationManager: AuthenticationManager
//     @EnvironmentObject private var pushNotificationService: PushNotificationService
//     @StateObject private var onboardingManager = OnboardingManager.shared
//     @State private var showingDailySummaryAlert = false
//     @State private var showingResetOnboardingAlert = false
//     @State private var showingSignOutAlert = false
//     
//     // MARK: - Homogeneous Background
//     var homogeneousBackground: Color {
//         let uvIndex = weatherViewModel.currentUVData?.uvIndex ?? 0
//         return UVColorUtils.getHomogeneousBackgroundColor(uvIndex)
//     }
//     
//     // Custom notification banner state
//     @State private var showingNotificationBanner = false
//     @State private var notificationBannerMessage = ""
//     @State private var notificationBannerType: NotificationBannerType = .info
//     
//     enum NotificationBannerType {
//         case success, warning, error, info
//         
//         var color: Color {
//             switch self {
//             case .success: return .green
//             case .warning: return .orange
//             case .error: return .red
//             case .info: return .blue
//             }
//         }
//         
//         var icon: String {
//             switch self {
//             case .success: return "checkmark.circle.fill"
//             case .warning: return "exclamationmark.triangle.fill"
//             case .error: return "xmark.circle.fill"
//             case .info: return "info.circle.fill"
//             }
//         }
//     }
//     
//     var body: some View {
//         NavigationView {
//             ZStack {
//                 // Homogeneous UV background
//                 homogeneousBackground
//                     .ignoresSafeArea()
//                 
//                 List {
//                 // Profile Section
//                 Section("Profile") {
//                     HStack {
//                         Image(systemName: "person.circle.fill")
//                             .font(.largeTitle)
//                             .foregroundColor(.orange)
//                         
//                         VStack(alignment: .leading, spacing: 2) {
//                             Text("Sun Safety User")
//                                 .font(.headline)
//                                 .fontWeight(.semibold)
//                             Text("Stay protected, stay healthy")
//                                 .font(.subheadline)
//                                 .foregroundColor(.secondary)
//                         }
//                         
//                         Spacer()
//                     }
//                     .padding(.vertical, 4)
//                 }
//                 
//                 // Notifications Section
//                 Section("Notifications") {
//                     HStack {
//                         Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash.fill")
//                             .foregroundColor(notificationManager.isAuthorized ? .green : .red)
//                         
//                         VStack(alignment: .leading, spacing: 2) {
//                             Text(notificationManager.isAuthorized ? "Local Notifications" : "Local Notifications Disabled")
//                                 .font(.subheadline)
//                                 .fontWeight(.medium)
//                             Text(notificationManager.isAuthorized ? "You'll receive UV alerts and reminders" : "Enable to get UV alerts and reminders")
//                                 .font(.caption)
//                                 .foregroundColor(.secondary)
//                         }
//                         
//                         Spacer()
//                         
//                         if !notificationManager.isAuthorized {
//                             Button("Enable") {
//                                 Task {
//                                     await notificationManager.requestNotificationPermission()
//                                 }
//                             }
//                             .buttonStyle(.borderedProminent)
//                             .controlSize(.small)
//                         }
//                     }
//                     .padding(.vertical, 4)
//                 }
//                 
//                 // Settings Section
//                 Section("Settings") {
//                     NavigationLink(destination: NotificationSettingsView()) {
//                         HStack {
//                             Image(systemName: "bell.badge")
//                                 .foregroundColor(.blue)
//                             Text("Notification Settings")
//                         }
//                     }
//                     
//                     NavigationLink(destination: EnvironmentalFactorsView()) {
//                         HStack {
//                             Image(systemName: "leaf.fill")
//                                 .foregroundColor(.green)
//                             Text("Environmental Factors")
//                         }
//                     }
//                 }
//                 
//                 // Data Section
//                 Section("Data") {
//                     Button(action: {
//                         showingDailySummaryAlert = true
//                     }) {
//                         HStack {
//                             Image(systemName: "chart.bar.fill")
//                                 .foregroundColor(.purple)
//                             Text("Daily Summary")
//                             Spacer()
//                         }
//                     }
//                     .foregroundColor(.primary)
//                     
//                     Button(action: {
//                         // Export data functionality
//                         showNotificationBanner(message: "Data export feature coming soon!", type: .info)
//                     }) {
//                         HStack {
//                             Image(systemName: "square.and.arrow.up")
//                                 .foregroundColor(.orange)
//                             Text("Export Data")
//                             Spacer()
//                         }
//                     }
//                     .foregroundColor(.primary)
//                 }
//                 
//                 // Account Section
//                 Section("Account") {
//                     Button(action: {
//                         showingResetOnboardingAlert = true
//                     }) {
//                         HStack {
//                             Image(systemName: "arrow.clockwise")
//                                 .foregroundColor(.blue)
//                             Text("Reset Onboarding")
//                             Spacer()
//                         }
//                     }
//                     .foregroundColor(.primary)
//                     
//                     Button(action: {
//                         showingSignOutAlert = true
//                     }) {
//                         HStack {
//                             Image(systemName: "rectangle.portrait.and.arrow.right")
//                                 .foregroundColor(.red)
//                             Text("Sign Out")
//                             Spacer()
//                         }
//                     }
//                     .foregroundColor(.primary)
//                 }
//                 
//                 // About Section
//                 Section("About") {
//                     HStack {
//                         Image(systemName: "info.circle")
//                             .foregroundColor(.gray)
//                         Text("Version")
//                         Spacer()
//                         Text("1.0.0")
//                             .foregroundColor(.secondary)
//                     }
//                     
//                     HStack {
//                         Image(systemName: "heart.fill")
//                             .foregroundColor(.red)
//                         Text("Made with ❤️ for sun safety")
//                         Spacer()
//                     }
//                 }
//                 }
//                 .listStyle(InsetGroupedListStyle())
//                 .scrollContentBackground(.hidden)
//             }
//             .navigationTitle("Me")
//             .navigationBarTitleDisplayMode(.large)
//         }
//         .alert("Daily Summary", isPresented: $showingDailySummaryAlert) {
//             Button("OK") { }
//         } message: {
//             Text("Your daily UV exposure summary will be available here.")
//         }
//         .alert("Reset Onboarding", isPresented: $showingResetOnboardingAlert) {
//             Button("Cancel", role: .cancel) { }
//             Button("Reset", role: .destructive) {
//                 onboardingManager.resetOnboarding()
//                 showNotificationBanner(message: "Onboarding reset successfully!", type: .success)
//             }
//         } message: {
//             Text("This will reset the onboarding flow. You'll see the welcome screens again.")
//         }
//         .alert("Sign Out", isPresented: $showingSignOutAlert) {
//             Button("Cancel", role: .cancel) { }
//             Button("Sign Out", role: .destructive) {
//                 Task {
//                     await authenticationManager.signOut()
//                 }
//             }
//         } message: {
//             Text("Are you sure you want to sign out?")
//         }
//         .overlay(
//             // Custom notification banner
//             VStack {
//                 if showingNotificationBanner {
//                     HStack {
//                         Image(systemName: notificationBannerType.icon)
//                             .foregroundColor(notificationBannerType.color)
//                         Text(notificationBannerMessage)
//                             .font(.subheadline)
//                         Spacer()
//                         Button("×") {
//                             withAnimation(.easeInOut(duration: 0.3)) {
//                                 showingNotificationBanner = false
//                             }
//                         }
//                         .font(.title2)
//                         .foregroundColor(.secondary)
//                     }
//                     .padding()
//                     .background(
//                         RoundedRectangle(cornerRadius: 12)
//                             .fill(.regularMaterial)
//                             .shadow(radius: 8)
//                     )
//                     .padding(.horizontal)
//                     .transition(.move(edge: .top).combined(with: .opacity))
//                 }
//                 Spacer()
//             }
//         )
//         .onAppear {
//             // Refresh data when view appears
//             Task {
//                 await weatherViewModel.refreshData()
//             }
//         }
//     }
//     
//     // MARK: - Helper Methods
//     
//     private func showNotificationBanner(message: String, type: NotificationBannerType) {
//         notificationBannerMessage = message
//         notificationBannerType = type
//         
//         withAnimation(.easeInOut(duration: 0.3)) {
//             showingNotificationBanner = true
//         }
//         
//         // Auto-hide after 3 seconds
//         DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//             withAnimation(.easeInOut(duration: 0.3)) {
//                 showingNotificationBanner = false
//             }
//         }
//     }
// } 