import Foundation
import SwiftUI

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var isOnboardingComplete = false
    @Published var currentStep = 0
    @Published var isDataLoading = false
    @Published var dataLoadProgress = 0.0
    
    private let locationManager: LocationManager
    private let notificationManager: NotificationManager
    
    private init() {
        print("📚 [OnboardingManager] 🚀 Initializing...")
        
        // Use shared instances to avoid duplicates
        self.locationManager = LocationManager.shared
        self.notificationManager = NotificationManager.shared
        loadOnboardingState()
        
        print("📚 [OnboardingManager] ✅ Initialization complete")
    }
    
    // MARK: - Onboarding Steps
    let onboardingSteps: [OnboardingStep] = [
        OnboardingStep(
            id: 0,
            title: "Welcome to Time to Burn",
            subtitle: "Your personal UV protection companion",
            description: "Get real-time UV data, track sun exposure, and stay safe in the sun with personalized alerts.",
            icon: "sun.max.fill",
            iconColor: .orange,
            actionTitle: "Get Started",
            actionType: .next
        ),
        OnboardingStep(
            id: 1,
            title: "Location Access",
            subtitle: "Get accurate UV data for your area",
            description: "We need your location to provide real-time UV index data and personalized sun safety recommendations.",
            icon: "location.fill",
            iconColor: .blue,
            actionTitle: "Allow Location",
            actionType: .location
        ),
        OnboardingStep(
            id: 2,
            title: "Stay Protected",
            subtitle: "Get notified about UV changes",
            description: "Receive alerts when UV levels are high, when to reapply sunscreen, and daily sun exposure summaries.",
            icon: "bell.fill",
            iconColor: .green,
            actionTitle: "Enable Notifications",
            actionType: .notifications
        ),
        OnboardingStep(
            id: 3,
            title: "You're All Set!",
            subtitle: "Ready to stay safe in the sun",
            description: "Time to Burn is now configured with your preferences. Start tracking your sun exposure and stay protected!",
            icon: "checkmark.circle.fill",
            iconColor: .green,
            actionTitle: "Start Using App",
            actionType: .complete
        )
    ]
    
    // MARK: - Public Methods
    func startOnboarding() {
        isOnboardingComplete = false
        currentStep = 0
        saveOnboardingState()
    }
    
    func nextStep() {
        if currentStep < onboardingSteps.count - 1 {
            currentStep += 1
            saveOnboardingState()
        }
    }
    
    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
            saveOnboardingState()
        }
    }
    
    func completeOnboarding() {
        isOnboardingComplete = true
        currentStep = 0
        saveOnboardingState()
    }
    
    func handleStepAction() async {
        let step = onboardingSteps[currentStep]
        
        switch step.actionType {
        case .next:
            nextStep()
            
        case .location:
            await requestLocationPermission()
            
        case .notifications:
            await requestNotificationPermission()
            
        case .complete:
            await loadBackgroundData()
            completeOnboarding()
        }
    }
    
    // MARK: - Permission Requests
    private func requestLocationPermission() async {
        print("OnboardingManager: Requesting location permission...")
        
        // Check current status
        let currentStatus = locationManager.authorizationStatus
        print("OnboardingManager: Current location status: \(currentStatus.rawValue)")
        
        // Request location permission
        locationManager.requestLocation()
        
        // Wait for the permission dialog to be processed
        // We'll wait up to 5 seconds for the user to respond
        for i in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let newStatus = locationManager.authorizationStatus
            if newStatus != currentStatus {
                print("OnboardingManager: Location status changed to: \(newStatus.rawValue)")
                break
            }
            
            print("OnboardingManager: Waiting for location permission response... (\(i + 1)/10)")
        }
        
        // Check final status
        let finalStatus = locationManager.authorizationStatus
        print("OnboardingManager: Final location status: \(finalStatus.rawValue)")
        
        // If location is granted, start loading weather data
        if finalStatus == .authorizedWhenInUse || finalStatus == .authorizedAlways {
            print("OnboardingManager: Location granted, loading background data...")
            await loadBackgroundData()
        } else {
            print("OnboardingManager: Location not granted")
        }
        
        nextStep()
    }
    
    private func requestNotificationPermission() async {
        print("OnboardingManager: Requesting notification permission...")
        
        let granted = await notificationManager.requestNotificationPermission()
        print("OnboardingManager: Notification permission result: \(granted)")
        
        if granted {
            print("OnboardingManager: Configuring default notification settings...")
            // Configure default notification settings
            notificationManager.notificationSettings.sunscreenRemindersEnabled = true
            notificationManager.notificationSettings.exposureWarningsEnabled = true
            notificationManager.notificationSettings.uvThresholdAlertsEnabled = true
            notificationManager.updateSettings(notificationManager.notificationSettings)
        }
        
        nextStep()
    }
    
    // MARK: - Background Data Loading
    private func loadBackgroundData() async {
        isDataLoading = true
        dataLoadProgress = 0.0
        
        // Simulate loading steps
        await updateProgress(0.2, "Initializing...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await updateProgress(0.4, "Loading weather data...")
        // Weather data will be loaded by the main app's WeatherViewModel
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        await updateProgress(0.6, "Setting up notifications...")
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        await updateProgress(0.8, "Finalizing setup...")
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        await updateProgress(1.0, "Complete!")
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        isDataLoading = false
    }
    
    private func updateProgress(_ progress: Double, _ message: String) async {
        await MainActor.run {
            dataLoadProgress = progress
        }
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
}

// MARK: - Supporting Types
struct OnboardingStep {
    let id: Int
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let iconColor: Color
    let actionTitle: String
    let actionType: OnboardingActionType
}

enum OnboardingActionType {
    case next
    case location
    case notifications
    case complete
} 