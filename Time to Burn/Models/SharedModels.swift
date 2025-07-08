import Foundation
import SwiftUI
import WeatherKit

// MARK: - Shared UV Data Model
struct UVData: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let uvIndex: Int
    
    enum CodingKeys: String, CodingKey {
        case date
        case uvIndex = "value"
    }

    init(from hourWeather: HourWeather) {
        self.date = hourWeather.date
        self.uvIndex = Int(hourWeather.uvIndex.value)
    }

    init(from currentWeather: CurrentWeather) {
        self.date = currentWeather.date
        self.uvIndex = Int(currentWeather.uvIndex.value)
    }
    
    init(uvIndex: Int, date: Date) {
        self.date = date
        self.uvIndex = uvIndex
    }
}

// MARK: - Shared UV Exposure Data Model
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

// MARK: - Shared Data Manager
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
            userDefaults?.set(encoded, forKey: "sharedUVData")
            userDefaults?.synchronize()
            print("🌞 [MainApp] Wrote shared data: \(encoded.count) bytes to app group UserDefaults")
        } else {
            print("❌ [MainApp] Failed to encode shared data")
        }
    }
    
    func loadSharedData() -> SharedUVData? {
        print("🌞 [MainApp] Attempting to read shared data from app group UserDefaults...")
        if let data = userDefaults?.data(forKey: "sharedUVData") {
            print("🌞 [MainApp] Read shared data: \(data.count) bytes from app group UserDefaults")
            if let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) {
                return decoded
            } else {
                print("❌ [MainApp] Failed to decode shared data from app group UserDefaults")
            }
        } else {
            print("🌞 [MainApp] No shared data found in app group UserDefaults")
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