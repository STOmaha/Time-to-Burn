import Foundation
import SwiftUI
import CoreLocation

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    @Published var isOnboardingComplete = false
    @Published var currentStep = 0
    @Published var isRequestingPermission = false
    @Published var isSigningIn = false
    @Published var signInError: Error?

    private let locationManager: LocationManager
    private let notificationManager: NotificationManager

    let totalSteps = 7  // Welcome, Location, Notifications, Sign In, Widget, Subscription, Ready

    private init() {
        self.locationManager = LocationManager.shared
        self.notificationManager = NotificationManager.shared
        loadOnboardingState()
        logInfo(.onboarding, "OnboardingManager initialized", data: [
            "isComplete": isOnboardingComplete,
            "currentStep": currentStep,
            "totalSteps": totalSteps
        ])
    }

    // MARK: - Navigation

    func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        let previousStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep += 1
        }
        saveOnboardingState()
        logInfo(.onboarding, "Step advanced", data: [
            "from": stepName(for: previousStep),
            "to": stepName(for: currentStep),
            "progress": "\(currentStep + 1)/\(totalSteps)"
        ])
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        let previousStep = currentStep
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
        saveOnboardingState()
        logInfo(.onboarding, "Step back", data: [
            "from": stepName(for: previousStep),
            "to": stepName(for: currentStep)
        ])
    }

    func completeOnboarding() {
        LogManager.shared.logFlowStart("Onboarding Complete", category: .onboarding)

        withAnimation(.easeInOut(duration: 0.3)) {
            isOnboardingComplete = true
        }
        currentStep = 0
        saveOnboardingState()

        logSuccess(.onboarding, "Onboarding completed successfully", data: [
            "locationAuthorized": isLocationAuthorized,
            "notificationsAuthorized": isNotificationAuthorized,
            "signedIn": isSignedIn
        ])

        // Trigger initial data fetch after onboarding
        Task {
            await performInitialDataFetch()
        }

        LogManager.shared.logFlowEnd("Onboarding Complete", success: true, category: .onboarding)
    }

    /// Fetch location and UV data after onboarding completes
    private func performInitialDataFetch() async {
        logInfo(.onboarding, "Starting initial data fetch...")

        // Request location update - weather refresh will happen via the onChange handler
        // in Time_to_BurnApp when onboarding completes
        locationManager.requestLocation()
        logInfo(.location, "Location update requested")

        // NOTE: We don't need to trigger weather refresh here because:
        // 1. Time_to_BurnApp has an onChange handler for onboardingComplete that triggers refresh
        // 2. WeatherViewModel initializes with initializeDataFlow() which fetches data
        // Posting refreshWeatherData notification here would cause duplicate refreshes

        logSuccess(.onboarding, "Initial data fetch triggered", data: [
            "locationRequested": "true"
        ])
    }

    /// Get step name for logging
    private func stepName(for step: Int) -> String {
        switch step {
        case 0: return "Welcome"
        case 1: return "Location"
        case 2: return "Notifications"
        case 3: return "Sign In"
        case 4: return "Widget"
        case 5: return "Subscription"
        case 6: return "Ready"
        default: return "Unknown"
        }
    }

    // MARK: - Sign In Status

    /// Check if user is authenticated (signed in with Apple)
    var isSignedIn: Bool {
        AuthenticationManager.shared.isAuthenticated
    }

    /// Called when sign in starts
    func setSigningIn(_ value: Bool) {
        isSigningIn = value
        if value {
            logInfo(.auth, "Sign in started from onboarding")
        }
    }

    /// Called when sign in completes successfully
    func signInCompleted() {
        signInError = nil
        logSuccess(.auth, "Sign in completed in onboarding", data: [
            "userId": AuthenticationManager.shared.userId?.uuidString.prefix(8).description ?? "unknown"
        ])
        nextStep()
    }

    /// Called when sign in fails
    func signInFailed(_ error: Error) {
        signInError = error
        logError(.auth, "Sign in failed in onboarding", data: [
            "error": error.localizedDescription
        ])
    }

    // MARK: - Permission Requests

    /// Request location permission - returns true if granted
    func requestLocationPermission() async -> Bool {
        logInfo(.onboarding, "Requesting location permission...")
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let currentStatus = locationManager.authorizationStatus

        // If already authorized, just proceed
        if currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways {
            logSuccess(.location, "Location already authorized", data: ["status": currentStatus.displayName])
            return true
        }

        // Request permission
        locationManager.requestLocation()
        logInfo(.location, "Location permission dialog shown")

        // Wait for user response (up to 30 seconds)
        for _ in 0..<60 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let newStatus = locationManager.authorizationStatus
            if newStatus != .notDetermined {
                let granted = newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways
                LogManager.shared.logPermissionRequest("Location", granted: granted, context: "Onboarding")
                return granted
            }
        }

        logWarning(.location, "Location permission request timed out")
        return false
    }

    /// Request notification permission - returns true if granted
    func requestNotificationPermission() async -> Bool {
        logInfo(.onboarding, "Requesting notification permission...")
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        let granted = await notificationManager.requestNotificationPermission()

        if granted {
            // Configure default notification settings
            notificationManager.notificationSettings.sunscreenRemindersEnabled = true
            notificationManager.notificationSettings.exposureWarningsEnabled = true
            notificationManager.notificationSettings.uvThresholdAlertsEnabled = true
            notificationManager.updateSettings(notificationManager.notificationSettings)
            logSuccess(.notifications, "Notification permission granted, defaults configured")
        } else {
            logWarning(.notifications, "Notification permission denied or skipped")
        }

        LogManager.shared.logPermissionRequest("Notifications", granted: granted, context: "Onboarding")
        return granted
    }

    // MARK: - Status Helpers

    var isLocationAuthorized: Bool {
        let status = locationManager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var isNotificationAuthorized: Bool {
        notificationManager.isAuthorized
    }

    // MARK: - Persistence

    private func loadOnboardingState() {
        let defaults = UserDefaults.standard
        isOnboardingComplete = defaults.bool(forKey: "onboardingComplete")
        currentStep = defaults.integer(forKey: "onboardingCurrentStep")
    }

    private func saveOnboardingState() {
        let defaults = UserDefaults.standard
        defaults.set(isOnboardingComplete, forKey: "onboardingComplete")
        defaults.set(currentStep, forKey: "onboardingCurrentStep")
    }

    // MARK: - Testing

    func resetOnboardingForTesting() {
        isOnboardingComplete = false
        currentStep = 0
        saveOnboardingState()
    }
}

// MARK: - CLAuthorizationStatus Extension

extension CLAuthorizationStatus {
    var displayName: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized Always"
        case .authorizedWhenInUse:
            return "Authorized When In Use"
        @unknown default:
            return "Unknown"
        }
    }
}
