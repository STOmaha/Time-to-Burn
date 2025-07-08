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
        print("🌞 [Widget SharedDataManager] 🚀 Initializing...")
        
        // Initialize UserDefaults with proper error handling
        if let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared") {
            self.userDefaults = userDefaults
            print("🌞 [Widget SharedDataManager] ✅ App Group UserDefaults initialized successfully")
        } else {
            self.userDefaults = nil
            print("🌞 [Widget SharedDataManager] ❌ Failed to initialize App Group UserDefaults")
        }
    }
    
    func saveSharedData(_ data: SharedUVData) {
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults?.set(encoded, forKey: "sharedUVData")
            
            // Beautiful console logging with emojis
            let uvEmoji = getUVEmoji(data.currentUVIndex)
            let statusEmoji = getStatusEmoji(data.exposureStatus)
            let timeToBurnText = data.timeToBurn == Int.max ? "∞" : "\(data.timeToBurn / 60)min"
            
            print("🌞 [Widget SharedDataManager] 💾 Saved UV Data:")
            print("   📊 UV Index: \(uvEmoji) \(data.currentUVIndex)")
            print("   ⏱️  Time to Burn: \(timeToBurnText)")
            print("   📍 Location: \(data.locationName)")
            print("   🎯 Status: \(statusEmoji) \(data.exposureStatus.rawValue)")
            print("   🕐 Last Updated: \(formatTime(data.lastUpdated))")
            print("   ──────────────────────────────────────")
        } else {
            print("❌ [Widget SharedDataManager] 💥 Failed to encode data")
        }
    }
    
    func loadSharedData() -> SharedUVData? {
        print("🌞 [Widget SharedDataManager] 🔍 Loading shared data...")
        
        // Try main UserDefaults first
        if let userDefaults = userDefaults {
            print("🌞 [Widget SharedDataManager] ✅ Main UserDefaults available")
            
            if let data = userDefaults.data(forKey: "sharedUVData") {
                print("🌞 [Widget SharedDataManager] 📦 Found data (\(data.count) bytes)")
                
                if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                    let uvEmoji = getUVEmoji(decoded.currentUVIndex)
                    let timeToBurnText = decoded.timeToBurn == Int.max ? "∞" : "\(decoded.timeToBurn / 60)min"
                    print("🌞 [Widget SharedDataManager] ✅ Successfully loaded shared data:")
                    print("   📊 UV Index: \(uvEmoji) \(decoded.currentUVIndex)")
                    print("   ⏱️  Time to Burn: \(timeToBurnText)")
                    print("   📍 Location: \(decoded.locationName)")
                    print("   ──────────────────────────────────────")
                    return decoded
                } else {
                    print("🌞 [Widget SharedDataManager] ❌ Failed to decode data from main UserDefaults")
                }
            } else {
                print("🌞 [Widget SharedDataManager] ⚠️  No data found in main UserDefaults")
            }
        } else {
            print("🌞 [Widget SharedDataManager] ❌ Main UserDefaults not available")
        }
        
        // Try alternative UserDefaults
        print("🌞 [Widget SharedDataManager] 🔄 Trying alternative UserDefaults...")
        if let alternativeUserDefaults = UserDefaults(suiteName: "group.Time-to-Burn.shared") {
            print("🌞 [Widget SharedDataManager] ✅ Alternative UserDefaults initialized")
            
            if let data = alternativeUserDefaults.data(forKey: "sharedUVData") {
                print("🌞 [Widget SharedDataManager] 📦 Found data in alternative UserDefaults (\(data.count) bytes)")
                
                if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                    let uvEmoji = getUVEmoji(decoded.currentUVIndex)
                    let timeToBurnText = decoded.timeToBurn == Int.max ? "∞" : "\(decoded.timeToBurn / 60)min"
                    print("🌞 [Widget SharedDataManager] ✅ Successfully loaded shared data (Alternative):")
                    print("   📊 UV Index: \(uvEmoji) \(decoded.currentUVIndex)")
                    print("   ⏱️  Time to Burn: \(timeToBurnText)")
                    print("   📍 Location: \(decoded.locationName)")
                    print("   ──────────────────────────────────────")
                    return decoded
                } else {
                    print("🌞 [Widget SharedDataManager] ❌ Failed to decode data from alternative UserDefaults")
                }
            } else {
                print("🌞 [Widget SharedDataManager] ⚠️  No data found in alternative UserDefaults")
            }
        } else {
            print("🌞 [Widget SharedDataManager] ❌ Failed to initialize alternative UserDefaults")
        }
        
        // Try standard UserDefaults as last resort
        print("🌞 [Widget SharedDataManager] 🔄 Trying standard UserDefaults as last resort...")
        if let data = UserDefaults.standard.data(forKey: "sharedUVData") {
            print("🌞 [Widget SharedDataManager] 📦 Found data in standard UserDefaults (\(data.count) bytes)")
            
            if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                let uvEmoji = getUVEmoji(decoded.currentUVIndex)
                let timeToBurnText = decoded.timeToBurn == Int.max ? "∞" : "\(decoded.timeToBurn / 60)min"
                print("🌞 [Widget SharedDataManager] ✅ Successfully loaded shared data (Standard):")
                print("   📊 UV Index: \(uvEmoji) \(decoded.currentUVIndex)")
                print("   ⏱️  Time to Burn: \(timeToBurnText)")
                print("   📍 Location: \(decoded.locationName)")
                print("   ──────────────────────────────────────")
                return decoded
            } else {
                print("🌞 [Widget SharedDataManager] ❌ Failed to decode data from standard UserDefaults")
            }
        } else {
            print("🌞 [Widget SharedDataManager] ⚠️  No data found in standard UserDefaults")
        }
        
        print("🌞 [Widget SharedDataManager] ❌ No shared data found in any UserDefaults")
        return nil
    }
    
    func clearSharedData() {
        userDefaults?.removeObject(forKey: "sharedUVData")
        print("🗑️ [Widget SharedDataManager] 🧹 Cleared shared data")
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