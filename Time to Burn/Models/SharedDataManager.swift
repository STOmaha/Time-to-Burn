import Foundation
import SwiftUI

// Shared data model for widget and main app communication
struct SharedUVData: Codable {
    let currentUVIndex: Int
    let timeToBurn: Int
    let elapsedTime: TimeInterval
    let totalExposureTime: TimeInterval
    let isTimerRunning: Bool
    let lastSunscreenApplication: Date?
    let sunscreenReapplyTimeRemaining: TimeInterval
    let exposureStatus: ExposureStatus
    let exposureProgress: Double
    let timestamp: Date
    let locationName: String
    let lastUpdated: Date
    let hourlyUVData: [UVData]?
    
    enum ExposureStatus: String, Codable, CaseIterable {
        case safe = "Safe"
        case warning = "Warning"
        case exceeded = "Exceeded"
        case noUV = "No UV"
        
        var color: Color {
            switch self {
            case .safe: return .green
            case .warning: return .orange
            case .exceeded: return .red
            case .noUV: return .blue
            }
        }
    }
    
    init(
        currentUVIndex: Int,
        timeToBurn: Int,
        elapsedTime: TimeInterval,
        totalExposureTime: TimeInterval,
        isTimerRunning: Bool,
        lastSunscreenApplication: Date?,
        sunscreenReapplyTimeRemaining: TimeInterval,
        exposureStatus: ExposureStatus,
        exposureProgress: Double,
        locationName: String,
        lastUpdated: Date,
        hourlyUVData: [UVData]? = nil
    ) {
        self.currentUVIndex = currentUVIndex
        self.timeToBurn = timeToBurn
        self.elapsedTime = elapsedTime
        self.totalExposureTime = totalExposureTime
        self.isTimerRunning = isTimerRunning
        self.lastSunscreenApplication = lastSunscreenApplication
        self.sunscreenReapplyTimeRemaining = sunscreenReapplyTimeRemaining
        self.exposureStatus = exposureStatus
        self.exposureProgress = exposureProgress
        self.timestamp = Date()
        self.locationName = locationName
        self.lastUpdated = lastUpdated
        self.hourlyUVData = hourlyUVData
    }
}

// Shared data manager for widget and app communication
class SharedDataManager: ObservableObject {
    static let shared = SharedDataManager()
    
    private let userDefaults: UserDefaults?
    
    private init() {
        // Initialize UserDefaults with proper error handling
        if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
            self.userDefaults = userDefaults
            print("🌞 [SharedDataManager] ✅ App Group UserDefaults initialized successfully")
        } else {
            self.userDefaults = nil
            print("🌞 [SharedDataManager] ⚠️  Failed to initialize App Group UserDefaults")
        }
    }
    
    func saveSharedData(_ data: SharedUVData) {
        if let encoded = try? JSONEncoder().encode(data) {
            // Save to app group UserDefaults
            userDefaults?.set(encoded, forKey: "sharedUVData")
            
            // Also save to standard UserDefaults as fallback
            UserDefaults.standard.set(encoded, forKey: "sharedUVData")
            
            // Beautiful console logging with emojis
            let uvEmoji = getUVEmoji(data.currentUVIndex)
            let statusEmoji = getStatusEmoji(data.exposureStatus)
            let timeToBurnText = data.timeToBurn == Int.max ? "∞" : "\(data.timeToBurn / 60)min"
            
            print("🌞 [SharedDataManager] 💾 Shared Data Updated:")
            print("   📊 UV Index: \(uvEmoji) \(data.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(timeToBurnText)")
            print("   📍 Location: \(data.locationName)")
            print("   🎯 Status: \(statusEmoji) \(data.exposureStatus.rawValue)")
            print("   🕐 Last Updated: \(formatTime(data.lastUpdated))")
            print("   ──────────────────────────────────────")
        } else {
            print("❌ [SharedDataManager] 💥 Failed to encode data")
        }
    }
    
    func loadSharedData() -> SharedUVData? {
        // Try main UserDefaults first
        if let data = userDefaults?.data(forKey: "sharedUVData") {
            if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                return decoded
            }
        }
        
        // Try alternative UserDefaults
        let alternativeUserDefaults = UserDefaults(suiteName: "group.Time-to-Burn.shared")
        if let data = alternativeUserDefaults?.data(forKey: "sharedUVData") {
            if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                return decoded
            }
        }
        
        return nil
    }
    
    func clearSharedData() {
        userDefaults?.removeObject(forKey: "sharedUVData")
        print("🗑️ [SharedDataManager] 🧹 Cleared shared data")
    }
    
    // MARK: - Helper Methods for Beautiful Logging
    
    private func getUVEmoji(_ uvIndex: Int) -> String {
        switch uvIndex {
        case 0: return "🌙"
        case 1...2: return "🌤️"
        case 3...5: return "☀️"
        case 6...7: return "🔥"
        case 8...10: return "☠️"
        default: return "💀"
        }
    }
    
    private func getStatusEmoji(_ status: SharedUVData.ExposureStatus) -> String {
        switch status {
        case .safe: return "✅"
        case .warning: return "⚠️"
        case .exceeded: return "🚨"
        case .noUV: return "🌙"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
} 