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
        exposureProgress: Double
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
    }
}

// Shared data manager for widget and app communication
class SharedDataManager: ObservableObject {
    static let shared = SharedDataManager()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.timetoburn.shared")
    
    private init() {}
    
    func saveSharedData(_ data: SharedUVData) {
        if let encoded = try? JSONEncoder().encode(data) {
            userDefaults?.set(encoded, forKey: "sharedUVData")
        }
    }
    
    func loadSharedData() -> SharedUVData? {
        guard let data = userDefaults?.data(forKey: "sharedUVData"),
              let decoded = try? JSONDecoder().decode(SharedUVData.self, from: data) else {
            return nil
        }
        return decoded
    }
    
    func clearSharedData() {
        userDefaults?.removeObject(forKey: "sharedUVData")
    }
} 