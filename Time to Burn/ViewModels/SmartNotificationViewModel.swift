import Foundation
import SwiftUI
import UserNotifications

@MainActor
class SmartNotificationViewModel: ObservableObject {
    static let shared = SmartNotificationViewModel()
    
    private let notificationManager = NotificationManager.shared
    private let environmentalDataService = EnvironmentalDataService.shared
    private let locationManager = LocationManager.shared
    
    @Published var currentRiskAssessment: UVRiskAssessment?
    @Published var pendingNotifications: [SmartNotification] = []
    @Published var notificationHistory: [SmartNotification] = []
    @Published var isProcessing = false
    @Published var lastAssessmentTime: Date?
    
    // Smart notification settings
    @Published var smartNotificationSettings = SmartNotificationSettings()
    
    private var backgroundTask: Task<Void, Never>?
    private var lastUVIndex: Int = 0
    private var lastRiskLevel: RiskLevel = .moderate
    
    private init() {
        loadSettings()
        setupNotificationCategories()
    }
    
    // MARK: - Main Assessment Methods
    
    /// Perform comprehensive UV risk assessment
    func performRiskAssessment(baseUVIndex: Int) async {
        print("🧠 [SmartNotificationViewModel] Starting risk assessment...")
        
        await MainActor.run {
            isProcessing = true
        }
        
        guard let location = locationManager.location else {
            print("🧠 [SmartNotificationViewModel] ❌ No location available")
            await MainActor.run { isProcessing = false }
            return
        }
        
        do {
            // Fetch environmental data
            let environmentalFactors = await environmentalDataService.fetchEnvironmentalData(for: location)
            
            guard let factors = environmentalFactors else {
                print("🧠 [SmartNotificationViewModel] ❌ Failed to fetch environmental data")
                await MainActor.run { isProcessing = false }
                return
            }
            
            // Generate risk factors and recommendations
            let riskFactors = UVRiskCalculator.generateRiskFactors(
                assessment: UVRiskAssessment(
                    baseUVIndex: baseUVIndex,
                    environmentalFactors: factors
                )
            )
            
            let recommendations = UVRiskCalculator.generateRecommendations(
                assessment: UVRiskAssessment(
                    baseUVIndex: baseUVIndex,
                    environmentalFactors: factors
                )
            )
            
            // Create comprehensive risk assessment
            let assessment = UVRiskAssessment(
                baseUVIndex: baseUVIndex,
                environmentalFactors: factors,
                riskFactors: riskFactors,
                recommendations: recommendations
            )
            
            await MainActor.run {
                self.currentRiskAssessment = assessment
                self.lastAssessmentTime = Date()
                self.isProcessing = false
                
                print("🧠 [SmartNotificationViewModel] ✅ Risk assessment completed!")
                print("   📊 Base UV: \(baseUVIndex)")
                print("   🔄 Adjusted UV: \(assessment.adjustedUVIndex)")
                print("   ⚠️ Risk Level: \(assessment.riskLevel.rawValue)")
                print("   📈 Risk Score: \(String(format: "%.2f", assessment.riskScore))")
                print("   ──────────────────────────────────────")
            }
            
            // Process smart notifications
            await processSmartNotifications(assessment: assessment)
            
        } catch {
            await MainActor.run {
                isProcessing = false
                print("🧠 [SmartNotificationViewModel] ❌ Error during risk assessment: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Smart Notification Processing
    
    /// Process and schedule smart notifications based on risk assessment
    private func processSmartNotifications(assessment: UVRiskAssessment) async {
        print("🧠 [SmartNotificationViewModel] Processing smart notifications...")
        
        // Check if we should send notifications
        guard shouldSendNotifications(for: assessment) else {
            print("🧠 [SmartNotificationViewModel] ⏭️ Notifications disabled or not needed")
            return
        }
        
        // Generate smart notifications
        let notifications = generateSmartNotifications(assessment: assessment)
        
        // Schedule notifications
        for notification in notifications {
            await scheduleSmartNotification(notification)
        }
        
        await MainActor.run {
            self.pendingNotifications = notifications
        }
        
        print("🧠 [SmartNotificationViewModel] ✅ Scheduled \(notifications.count) smart notifications")
    }
    
    /// Determine if notifications should be sent
    private func shouldSendNotifications(for assessment: UVRiskAssessment) -> Bool {
        // Check if smart notifications are enabled
        guard smartNotificationSettings.enabled else { return false }
        
        // Check if risk level has changed significantly
        let riskLevelChanged = assessment.riskLevel != lastRiskLevel
        let uvChangedSignificantly = abs(assessment.adjustedUVIndex - lastUVIndex) >= smartNotificationSettings.uvChangeThreshold
        
        // Check if risk level meets minimum threshold
        let meetsThreshold = assessment.riskLevel.rawValue >= smartNotificationSettings.minimumRiskLevel.rawValue
        
        // Update last values
        lastRiskLevel = assessment.riskLevel
        lastUVIndex = assessment.adjustedUVIndex
        
        return (riskLevelChanged || uvChangedSignificantly) && meetsThreshold
    }
    
    /// Generate smart notifications based on risk assessment
    private func generateSmartNotifications(assessment: UVRiskAssessment) -> [SmartNotification] {
        var notifications: [SmartNotification] = []
        
        // Risk level change notification
        if assessment.riskLevel != lastRiskLevel {
            notifications.append(createRiskLevelNotification(assessment: assessment))
        }
        
        // Environmental factor notifications
        for riskFactor in assessment.riskFactors {
            if riskFactor.severity == .high || riskFactor.severity == .extreme {
                notifications.append(createEnvironmentalFactorNotification(riskFactor: riskFactor, assessment: assessment))
            }
        }
        
        // Recommendation notifications
        let criticalRecommendations = assessment.recommendations.filter { $0.priority == .critical || $0.priority == .high }
        for recommendation in criticalRecommendations.prefix(2) { // Limit to 2 most critical
            notifications.append(createRecommendationNotification(recommendation: recommendation, assessment: assessment))
        }
        
        // Educational notifications (occasional)
        if shouldShowEducationalNotification() {
            notifications.append(createEducationalNotification(assessment: assessment))
        }
        
        return notifications
    }
    
    // MARK: - Notification Creation
    
    /// Create risk level change notification
    private func createRiskLevelNotification(assessment: UVRiskAssessment) -> SmartNotification {
        let title = "UV Risk Level Changed"
        let body = "Current UV risk is \(assessment.riskLevel.rawValue). \(assessment.riskLevel.description)"
        
        return SmartNotification(
            type: .riskLevelChange,
            title: title,
            body: body,
            priority: assessment.riskLevel == .extreme ? .critical : .high,
            riskAssessment: assessment,
            scheduledTime: Date()
        )
    }
    
    /// Create environmental factor notification
    private func createEnvironmentalFactorNotification(riskFactor: RiskFactor, assessment: UVRiskAssessment) -> SmartNotification {
        let title = "Environmental UV Risk"
        let body = "\(riskFactor.description). \(riskFactor.mitigation)"
        
        return SmartNotification(
            type: .environmentalFactor,
            title: title,
            body: body,
            priority: riskFactor.severity == .extreme ? .critical : .high,
            riskAssessment: assessment,
            scheduledTime: Date()
        )
    }
    
    /// Create recommendation notification
    private func createRecommendationNotification(recommendation: Recommendation, assessment: UVRiskAssessment) -> SmartNotification {
        let title = recommendation.title
        let body = recommendation.description
        
        return SmartNotification(
            type: .recommendation,
            title: title,
            body: body,
            priority: convertPriority(recommendation.priority),
            riskAssessment: assessment,
            scheduledTime: Date()
        )
    }
    
    /// Create educational notification
    private func createEducationalNotification(assessment: UVRiskAssessment) -> SmartNotification {
        let educationalContent = getEducationalContent(for: assessment)
        
        return SmartNotification(
            type: .educational,
            title: "UV Safety Tip",
            body: educationalContent,
            priority: .medium,
            riskAssessment: assessment,
            scheduledTime: Date()
        )
    }
    
    // MARK: - Notification Scheduling
    
    /// Schedule a smart notification
    private func scheduleSmartNotification(_ notification: SmartNotification) async {
        guard notificationManager.isAuthorized else {
            print("🧠 [SmartNotificationViewModel] ❌ Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.categoryIdentifier = "SMART_NOTIFICATION"
        
        // Add user info for notification handling
        content.userInfo = [
            "notificationType": notification.type.rawValue,
            "riskLevel": notification.riskAssessment.riskLevel.rawValue,
            "adjustedUV": notification.riskAssessment.adjustedUVIndex
        ]
        
        // Schedule with slight delay to avoid notification spam
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "smart_notification_\(Date().timeIntervalSince1970)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🧠 [SmartNotificationViewModel] ✅ Scheduled: \(notification.title)")
        } catch {
            print("🧠 [SmartNotificationViewModel] ❌ Failed to schedule notification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Educational Content
    
    /// Get educational content based on assessment
    private func getEducationalContent(for assessment: UVRiskAssessment) -> String {
        let riskLevel = assessment.riskLevel
        
        switch riskLevel {
        case .veryLow, .low:
            return "Did you know? Even on cloudy days, up to 80% of UV rays can penetrate clouds. Always protect your skin!"
            
        case .moderate:
            return "UV rays are strongest between 10 AM and 4 PM. Seek shade during these hours for better protection."
            
        case .high:
            return "High UV conditions require extra protection. Remember: sunscreen, protective clothing, and shade are your best friends!"
            
        case .veryHigh, .extreme:
            return "Extreme UV conditions! The sun's rays are at their most intense. Consider postponing outdoor activities if possible."
        }
    }
    
    /// Determine if educational notification should be shown
    private func shouldShowEducationalNotification() -> Bool {
        // Show educational notifications occasionally (20% chance)
        return Double.random(in: 0...1) < 0.2
    }
    
    // MARK: - Settings Management
    
    /// Load smart notification settings
    private func loadSettings() {
        let userDefaults = UserDefaults.standard
        smartNotificationSettings.enabled = userDefaults.bool(forKey: "smartNotificationsEnabled")
        smartNotificationSettings.uvChangeThreshold = userDefaults.integer(forKey: "uvChangeThreshold")
        
        if let riskLevelString = userDefaults.string(forKey: "minimumRiskLevel"),
           let riskLevel = RiskLevel(rawValue: riskLevelString) {
            smartNotificationSettings.minimumRiskLevel = riskLevel
        }
    }
    
    /// Save smart notification settings
    func saveSettings() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(smartNotificationSettings.enabled, forKey: "smartNotificationsEnabled")
        userDefaults.set(smartNotificationSettings.uvChangeThreshold, forKey: "uvChangeThreshold")
        userDefaults.set(smartNotificationSettings.minimumRiskLevel.rawValue, forKey: "minimumRiskLevel")
    }
    
    // MARK: - Notification Categories
    
    /// Setup smart notification categories
    private func setupNotificationCategories() {
        let smartNotificationCategory = UNNotificationCategory(
            identifier: "SMART_NOTIFICATION",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_DETAILS",
                    title: "View Details",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: [.destructive]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([smartNotificationCategory])
    }
    
    // MARK: - Background Processing
    
    /// Start background processing
    func startBackgroundProcessing() {
        backgroundTask = Task {
            while !Task.isCancelled {
                // Perform periodic risk assessments
                if let currentUV = getCurrentUVIndex() {
                    await performRiskAssessment(baseUVIndex: currentUV)
                }
                
                // Wait before next assessment
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000) // 30 minutes
            }
        }
    }
    
    /// Stop background processing
    func stopBackgroundProcessing() {
        backgroundTask?.cancel()
        backgroundTask = nil
    }
    
    /// Get current UV index (placeholder - would integrate with weather service)
    private func getCurrentUVIndex() -> Int? {
        // This would integrate with your existing weather service
        // For now, return a placeholder
        return nil
    }
    
    /// Convert Recommendation.Priority to SmartNotification.Priority
    private func convertPriority(_ priority: Recommendation.Priority) -> SmartNotification.Priority {
        switch priority {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        case .critical: return .critical
        }
    }
}

// MARK: - Smart Notification Model

struct SmartNotification: Identifiable, Codable {
    let id: UUID
    let type: NotificationType
    let title: String
    let body: String
    let priority: Priority
    let riskAssessment: UVRiskAssessment
    let scheduledTime: Date
    let isDelivered: Bool
    
    init(type: NotificationType, title: String, body: String, priority: Priority, riskAssessment: UVRiskAssessment, scheduledTime: Date) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.body = body
        self.priority = priority
        self.riskAssessment = riskAssessment
        self.scheduledTime = scheduledTime
        self.isDelivered = false
    }
    
    enum NotificationType: String, Codable, CaseIterable {
        case riskLevelChange = "Risk Level Change"
        case environmentalFactor = "Environmental Factor"
        case recommendation = "Recommendation"
        case educational = "Educational"
        case warning = "Warning"
        case alert = "Alert"
    }
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
}

// MARK: - Smart Notification Settings

struct SmartNotificationSettings {
    var enabled: Bool = true
    var uvChangeThreshold: Int = 2 // UV index change threshold
    var minimumRiskLevel: RiskLevel = .moderate
    var educationalFrequency: Double = 0.2 // 20% chance
    var maxNotificationsPerHour: Int = 3
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
} 