import SwiftUI
import AuthenticationServices

struct MeView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @EnvironmentObject private var notificationManager: NotificationManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var authenticationManager: AuthenticationManager
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var developerTools = DeveloperTools.shared
    @State private var showingDailySummaryAlert = false
    @State private var showingResetOnboardingAlert = false
    @State private var showingFullResetAlert = false
    
    // MARK: - Homogeneous Background
    var homogeneousBackground: Color {
        let uvIndex = weatherViewModel.currentUVData?.uvIndex ?? 0
        return UVColorUtils.getHomogeneousBackgroundColor(uvIndex)
    }
    
    // Custom notification banner state
    @State private var showingNotificationBanner = false
    @State private var notificationBannerMessage = ""
    @State private var notificationBannerType: NotificationBannerType = .info
    
    enum NotificationBannerType {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Homogeneous UV background
                homogeneousBackground
                    .ignoresSafeArea()
                
                List {
                    // Profile Section
                    Section("Profile") {
                        HStack {
                            Image(systemName: authenticationManager.isAuthenticated ? "person.circle.fill" : "person.circle")
                                .font(.largeTitle)
                                .foregroundColor(authenticationManager.isAuthenticated ? .green : .orange)

                            VStack(alignment: .leading, spacing: 2) {
                                if authenticationManager.isAuthenticated {
                                    Text(authenticationManager.userName ?? authenticationManager.userEmail ?? "Signed In")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text("Cloud sync enabled")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Sun Safety User")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Text("Sign in to enable cloud sync")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Settings Section
                    Section("Settings") {
                        NavigationLink(destination: EnvironmentalFactorsView()) {
                            HStack {
                                Image(systemName: "leaf.fill")
                                    .foregroundColor(.green)
                                Text("Environmental Factors")
                            }
                        }
                        
                        // Unit System Picker
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.orange)
                            Text("Units")
                            
                            Spacer()
                            
                            Picker("Units", selection: $settingsManager.isMetricUnits) {
                                Text("Imperial").tag(false)
                                Text("Metric").tag(true)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 140)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Data Section
                    Section("Data") {
                        Button(action: {
                            showingDailySummaryAlert = true
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.purple)
                                Text("Daily Summary")
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            // Export data functionality
                            showNotificationBanner(message: "Data export feature coming soon!", type: .info)
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.orange)
                                Text("Export Data")
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    // Account Section
                    Section("Account") {
                        if authenticationManager.isAuthenticated {
                            // Show sign out button
                            Button(action: {
                                Task {
                                    try? await authenticationManager.signOut()
                                    showNotificationBanner(message: "Signed out successfully", type: .info)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.red)
                                    Text("Sign Out")
                                    Spacer()
                                    if authenticationManager.isLoading {
                                        ProgressView()
                                    }
                                }
                            }
                            .foregroundColor(.red)
                        } else {
                            // Not authenticated - show Sign in with Apple button
                            SignInWithAppleButton(.signIn) { request in
                                print("🍎 [MeView] SignInWithAppleButton - configuring request")
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                print("🍎 [MeView] SignInWithAppleButton - onCompletion called")
                                switch result {
                                case .success(let authorization):
                                    print("🍎 [MeView] SignInWithAppleButton - SUCCESS, calling authenticationManager")
                                    Task {
                                        do {
                                            try await authenticationManager.signInWithApple(authorization: authorization)
                                            print("🍎 [MeView] ✅ Sign in completed successfully")
                                            showNotificationBanner(message: "Signed in successfully!", type: .success)
                                        } catch {
                                            print("🍎 [MeView] ❌ Sign in error: \(error)")
                                            showNotificationBanner(message: "Sign in failed: \(error.localizedDescription)", type: .error)
                                        }
                                    }
                                case .failure(let error):
                                    print("🍎 [MeView] ❌ SignInWithAppleButton FAILURE: \(error)")
                                    showNotificationBanner(message: "Sign in failed: \(error.localizedDescription)", type: .error)
                                }
                            }
                            .signInWithAppleButtonStyle(.black)
                            .frame(height: 45)
                            .cornerRadius(8)
                        }

                        Button(action: {
                            showingResetOnboardingAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.blue)
                                Text("Reset Onboarding")
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    #if DEBUG
                    // Developer Testing Section (only visible in debug builds)
                    Section("Supabase Tests") {
                        // Run All Tests Button
                        Button(action: {
                            Task {
                                let result = await developerTools.runAllTests()
                                showNotificationBanner(message: result.success ? "All tests passed!" : "Some tests failed - check results", type: result.success ? .success : .warning)
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Run All Tests")
                                        .fontWeight(.semibold)
                                    Text("Connection, Profile, Location, Subscription")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if developerTools.isTesting {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(developerTools.isTesting)

                        // Test Connection
                        Button(action: {
                            Task {
                                let result = await developerTools.testSupabaseConnection()
                                showNotificationBanner(message: result.message, type: result.success ? .success : .error)
                            }
                        }) {
                            HStack {
                                Image(systemName: "network")
                                    .foregroundColor(.blue)
                                Text("Test Connection")
                                Spacer()
                            }
                        }
                        .disabled(developerTools.isTesting)

                        // Test Profile
                        Button(action: {
                            Task {
                                let result = await developerTools.testUserProfile()
                                showNotificationBanner(message: result.message, type: result.success ? .success : .error)
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle")
                                    .foregroundColor(.purple)
                                Text("Test User Profile")
                                Spacer()
                            }
                        }
                        .disabled(developerTools.isTesting)

                        // Test Location Sync
                        Button(action: {
                            Task {
                                let result = await developerTools.testLocationSync()
                                showNotificationBanner(message: result.message, type: result.success ? .success : .error)
                            }
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.orange)
                                Text("Test Location Sync")
                                Spacer()
                            }
                        }
                        .disabled(developerTools.isTesting)

                        // Test Subscription
                        Button(action: {
                            Task {
                                let result = await developerTools.testSubscription()
                                showNotificationBanner(message: result.message, type: result.success ? .success : .error)
                            }
                        }) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                    .foregroundColor(.green)
                                Text("Test Subscription")
                                Spacer()
                            }
                        }
                        .disabled(developerTools.isTesting)

                        // Full Debug Test
                        Button(action: {
                            Task {
                                let result = await developerTools.runFullDebugTest()
                                showNotificationBanner(message: result.message, type: .info)
                            }
                        }) {
                            HStack {
                                Image(systemName: "ladybug.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Full Debug Test")
                                    Text("Detailed output in console")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .disabled(developerTools.isTesting)

                        // Show last test result
                        if !developerTools.lastTestResult.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last Result:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(developerTools.lastTestResult)
                                    .font(.caption)
                                    .foregroundColor(developerTools.lastTestSuccess ? .green : .red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 4)
                        }

                        // Sync Status
                        VStack(alignment: .leading, spacing: 4) {
                            Text(developerTools.getSyncStatusInfo())
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Reset Options") {
                        // Full Reset Button
                        Button(action: {
                            showingFullResetAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Full Reset (Fresh Install)")
                                        .foregroundColor(.red)
                                    Text("Deletes ALL local & cloud data")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if developerTools.isResetting {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(developerTools.isResetting)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(.gray)
                                Text("Reset iOS Permissions")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            Text("To fully test fresh install: Go to iOS Settings → General → Transfer or Reset iPhone → Reset → Reset Location & Privacy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    #endif

                    // About Section
                    Section("About") {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.gray)
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Made with ❤️ for sun safety")
                            Spacer()
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Daily Summary", isPresented: $showingDailySummaryAlert) {
            Button("OK") { }
        } message: {
            Text("Your daily UV exposure summary will be available here.")
        }
        .alert("Reset Onboarding", isPresented: $showingResetOnboardingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                onboardingManager.resetOnboardingForTesting()
                showNotificationBanner(message: "Onboarding reset! Force close and reopen the app to see onboarding flow.", type: .success)
            }
        } message: {
            Text("This will reset the onboarding flow and you'll see the welcome screens again. Force close the app (swipe up and swipe away) and reopen it to see the onboarding. Note: iOS system permissions cannot be reset programmatically.")
        }
        .alert("Full Reset - Fresh Install", isPresented: $showingFullResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                Task {
                    let success = await developerTools.performFullReset()
                    if success {
                        showNotificationBanner(message: "Full reset complete! Force close and reopen the app.", type: .success)
                    } else {
                        showNotificationBanner(message: "Reset failed: \(developerTools.resetError?.localizedDescription ?? "Unknown error")", type: .error)
                    }
                }
            }
        } message: {
            Text("This will DELETE ALL DATA:\n\n• Sign out of your account\n• Delete all Supabase data (profile, subscription, locations)\n• Clear all local settings\n• Reset onboarding\n\nYou'll need to sign in again and go through onboarding. This cannot be undone!")
        }
        .overlay(
            // Custom notification banner
            VStack {
                if showingNotificationBanner {
                    HStack {
                        Image(systemName: notificationBannerType.icon)
                            .foregroundColor(notificationBannerType.color)
                        Text(notificationBannerMessage)
                            .font(.subheadline)
                        Spacer()
                        Button("×") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingNotificationBanner = false
                            }
                        }
                        .font(.title2)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                            .shadow(radius: 8)
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
        )
        .onAppear {
            // Refresh data when view appears
            Task {
                await weatherViewModel.refreshData()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showNotificationBanner(message: String, type: NotificationBannerType) {
        notificationBannerMessage = message
        notificationBannerType = type
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showingNotificationBanner = true
        }
        
        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingNotificationBanner = false
            }
        }
    }
} 